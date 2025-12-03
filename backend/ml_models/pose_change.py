import os
import sys
import cv2
import torch
import numpy as np
import math
import time
import requests
from PIL import Image
from io import BytesIO

# ML Imports - TFLite
# Priority given to full TensorFlow if available, then tflite-runtime
try:
    import tensorflow.lite as tflite
except ImportError:
    try:
        import tflite_runtime.interpreter as tflite
    except ImportError:
        print("Error: Neither 'tensorflow' nor 'tflite-runtime' found.")
        print("Please install one: `pip install tensorflow` OR `pip install tflite-runtime`")
        raise

# ML Imports - PyTorch/HuggingFace (Kept as requested)
from mobile_sam import sam_model_registry, SamPredictor
from diffusers import StableDiffusionControlNetInpaintPipeline, ControlNetModel, UniPCMultistepScheduler

class GeometryHelper:
    @staticmethod
    def get_angle(p1, p2):
        """Returns angle in degrees between two points"""
        return math.degrees(math.atan2(p2[1] - p1[1], p2[0] - p1[0]))

    @staticmethod
    def get_extended_point(start, end, factor=0.3):
        """Extends a vector beyond the end point"""
        v = np.array(end[:2]) - np.array(start[:2])
        return np.array(end[:2]) + v * factor

class MoveNetPoseHelper:
    """
    Replaces HolisticHelper. Uses tflite-runtime to run MoveNet 
    instead of Mediapipe or TensorFlow Hub.
    """
    def __init__(self, model_path='movenet_lightning.tflite'):
        self.colors = [[255, 0, 85], [255, 0, 0], [255, 85, 0], [255, 170, 0], [255, 255, 0],
                       [170, 255, 0], [85, 255, 0], [0, 255, 0], [0, 255, 85], [0, 255, 170],
                       [0, 255, 255], [0, 170, 255], [0, 85, 255], [0, 0, 255], [255, 0, 170],
                       [170, 0, 255], [255, 0, 255], [85, 0, 255]]
        
        # Load TFLite Model
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file '{model_path}' not found. Please place it in the script directory.")

        self.interpreter = tflite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()

        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        # MoveNet Thunder usually expects 256x256, Lightning 192x192
        self.input_size = self.input_details[0]['shape'][1] 

    def process_image(self, image_pil):
        """
        Preprocesses image, runs inference, and returns keypoints + shape.
        Returns: (keypoints_normalized_coco_format, original_shape)
        """
        image_np = np.array(image_pil)
        original_h, original_w, _ = image_np.shape

        # Resize and Pad to square while maintaining aspect ratio
        input_image = cv2.resize(image_np, (self.input_size, self.input_size))
        input_image = np.expand_dims(input_image, axis=0)
        
        # MoveNet expects int32 or float32 depending on version, usually uint8 for quant or float for others
        # Thunder int8 expects uint8, Float models expect float32. 
        # Checking input dtype expectation:
        if self.input_details[0]['dtype'] == np.float32:
            input_image = (np.float32(input_image) - 127.5) / 127.5
        
        # Inference
        self.interpreter.set_tensor(self.input_details[0]['index'], input_image)
        self.interpreter.invoke()
        
        # Output is [1, 1, 17, 3] -> [17, 3] (y, x, score)
        keypoints_with_scores = self.interpreter.get_tensor(self.output_details[0]['index'])[0, 0]
        
        return keypoints_with_scores, (original_h, original_w, 3)

    def get_coco_keypoints(self, results, shape):
        """
        Converts MoveNet normalized output (y, x, score) to pixel coordinates (x, y, score).
        MoveNet output is already COCO topology, so no remapping needed, just scaling.
        """
        keypoints_norm = results # It's just the array from process_image
        H, W, _ = shape
        
        kps = np.zeros((17, 3))
        
        for idx in range(17):
            y_norm, x_norm, score = keypoints_norm[idx]
            kps[idx] = [x_norm * W, y_norm * H, score]
            
        return kps

    def draw_skeleton(self, keypoints, shape):
        """
        Draws the skeleton using OpenPose-style connections based on COCO keypoints.
        """
        H, W, _ = shape
        canvas = np.zeros((H, W, 3), dtype=np.uint8)
        
        # COCO Keypoint Indices:
        # 0:nose, 1:l_eye, 2:r_eye, 3:l_ear, 4:r_ear, 5:l_sho, 6:r_sho, 
        # 7:l_elb, 8:r_elb, 9:l_wri, 10:r_wri, 11:l_hip, 12:r_hip, 
        # 13:l_knee, 14:r_knee, 15:l_ank, 16:r_ank
        
        # Create OpenPose specific mapping for drawing if desired, 
        # or calculate neck position manually as MoveNet doesn't provide it.
        l_sho, r_sho = keypoints[5], keypoints[6]
        neck = [(l_sho[0] + r_sho[0]) / 2, (l_sho[1] + r_sho[1]) / 2, 1.0]
        
        # Construct the drawing list including the calculated neck
        # Note: This list structure attempts to match the visual style of the original code
        # Original code mapped indices to a specific 'op_kps' list.
        # COCO 0->0, Neck->1, R_Sho->2(6), R_Elb->3(8), R_Wri->4(10), L_Sho->5(5), L_Elb->6(7), L_Wri->7(9)
        # R_Hip->8(12), R_Knee->9(14), R_Ank->10(16), L_Hip->11(11), L_Knee->12(13), L_Ank->13(15)
        # R_Eye->14(2), L_Eye->15(1), R_Ear->16(4), L_Ear->17(3)
        
        op_kps = [
            keypoints[0], neck, keypoints[6], keypoints[8], keypoints[10], 
            keypoints[5], keypoints[7], keypoints[9], keypoints[12], 
            keypoints[14], keypoints[16], keypoints[11], keypoints[13], 
            keypoints[15], keypoints[2], keypoints[1], keypoints[4], keypoints[3]
        ]
        
        # Defined pairs for drawing lines
        pairs = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10),
                 (1, 11), (11, 12), (12, 13), (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]

        for i, (s, e) in enumerate(pairs):
            # MoveNet scores are usually lower than MP, adjusted threshold to 0.2
            if op_kps[s][2] > 0.2 and op_kps[e][2] > 0.2:
                pt1 = (int(op_kps[s][0]), int(op_kps[s][1]))
                pt2 = (int(op_kps[e][0]), int(op_kps[e][1]))
                cv2.line(canvas, pt1, pt2, self.colors[i%18], 3, cv2.LINE_AA)
        
        for i, kp in enumerate(op_kps):
            if kp[2] > 0.2: 
                cv2.circle(canvas, (int(kp[0]), int(kp[1])), 4, self.colors[i%18], -1)
                
        return canvas
    
class PoseCorrectionPipeline:
    def __init__(self, device='cuda'):
        self.device = device if torch.cuda.is_available() else 'cpu'
        print(f"🚀 Initializing PoseCorrectionPipeline on {self.device}...")
        
        # 1. Ensure MobileSAM Weights exist
        self._check_weights()
        
        # 2. Load Helpers (Switched to MoveNet)
        self.pose_helper = MoveNetPoseHelper()
        
        # 3. Load MobileSAM
        print("⏳ Loading MobileSAM...")
        self.sam = sam_model_registry["vit_t"](checkpoint="mobile_sam.pt")
        self.sam.to(device=self.device)
        self.sam.eval()
        self.sam_predictor = SamPredictor(self.sam)
        
        # 4. Load Diffusers/ControlNet
        print("⏳ Loading ControlNet & Stable Diffusion...")
        self.controlnet = ControlNetModel.from_pretrained(
            "lllyasviel/control_v11p_sd15_openpose", 
            torch_dtype=torch.float16 if self.device == 'cuda' else torch.float32
        )
        self.pipe = StableDiffusionControlNetInpaintPipeline.from_pretrained(
            "Lykon/dreamshaper-8-inpainting", 
            controlnet=self.controlnet, 
            torch_dtype=torch.float16 if self.device == 'cuda' else torch.float32, 
            safety_checker=None
        ).to(self.device)
        self.pipe.scheduler = UniPCMultistepScheduler.from_config(self.pipe.scheduler.config)
        
        # Enable optimizations
        if self.device == 'cuda':
            self.pipe.enable_model_cpu_offload()
            
        print("✅ Models Loaded Successfully.")

    def _check_weights(self):
        if not os.path.exists("mobile_sam.pt"):
            print("⬇️ Downloading MobileSAM weights...")
            url = "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt"
            response = requests.get(url)
            with open("mobile_sam.pt", "wb") as f:
                f.write(response.content)

    def _get_person_mask(self, image_np, keypoints):
        self.sam_predictor.set_image(image_np)
        input_points = np.array([
            keypoints[0][:2], keypoints[5][:2], keypoints[6][:2],
            keypoints[11][:2], keypoints[12][:2]
        ])
        input_labels = np.array([1, 1, 1, 1, 1])
        masks, _, _ = self.sam_predictor.predict(
            point_coords=input_points, 
            point_labels=input_labels, 
            multimask_output=False
        )
        return masks[0].astype(np.uint8) * 255

    def _make_square(self, img, target_size=512):
        width, height = img.size
        max_dim = max(width, height)
        new_img = Image.new('RGB', (max_dim, max_dim), (255, 255, 255))
        new_img.paste(img, ((max_dim - width) // 2, (max_dim - height) // 2))
        return new_img.resize((target_size, target_size))
    
    def _restore_original_dimensions(self, processed_512, orig_w, orig_h):
        # 1. compute original square size
        max_dim = max(orig_w, orig_h)
        # 2. scale factor to go from square → 512
        scale_factor = 512 / max_dim
        # 3. compute padding in original square
        pad_x = (max_dim - orig_w) // 2
        pad_y = (max_dim - orig_h) // 2
        # 4. scale padding
        scaled_pad_x = int(pad_x * scale_factor)
        scaled_pad_y = int(pad_y * scale_factor)
        # 5. compute crop region in processed image
        crop_left   = scaled_pad_x
        crop_top    = scaled_pad_y
        crop_right  = scaled_pad_x + int(orig_w * scale_factor)
        crop_bottom = scaled_pad_y + int(orig_h * scale_factor)

        cropped = processed_512.crop((crop_left, crop_top, crop_right, crop_bottom))
        # 6. upscale back to original dimensions
        restored = cropped.resize((orig_w, orig_h), Image.LANCZOS)
        return restored

    def _draw_synthetic_hand(self, canvas, elbow_pt, wrist_pt, scale_factor=1.0):
        vec_x = wrist_pt[0] - elbow_pt[0]
        vec_y = wrist_pt[1] - elbow_pt[1]
        arm_len = np.sqrt(vec_x**2 + vec_y**2)

        if arm_len == 0: return canvas

        dir_x = vec_x / arm_len
        dir_y = vec_y / arm_len
        base_angle = np.arctan2(dir_y, dir_x)

        total_hand_len = arm_len * 0.35 * scale_factor
        palm_len = total_hand_len * 0.2
        palm_radius = int(palm_len * 0.9)
        finger_angles = [40, 0 , 0, -25, -50]
        colors = [(0, 0, 255), (255, 255, 0), (0, 255, 0), (0, 165, 255), (0, 0, 255)]

        wrist_int = (int(wrist_pt[0]), int(wrist_pt[1]))
        elbow_int = (int(elbow_pt[0]), int(elbow_pt[1]))

        erase_radius = int(total_hand_len * 0.6)
        cv2.circle(canvas, wrist_int, erase_radius, (0, 0, 0), -1)
        cv2.line(canvas, elbow_int, wrist_int, (0, 165, 255), 3)
        cv2.circle(canvas, wrist_int, palm_radius, (0, 0, 255), -1)

        for i, angle_deg in enumerate(finger_angles):
            total_angle = base_angle + np.radians(angle_deg)
            knuckle_x = wrist_pt[0] + (np.cos(total_angle) * palm_len)
            knuckle_y = wrist_pt[1] + (np.sin(total_angle) * palm_len)
            knuckle_int = (int(knuckle_x), int(knuckle_y))
            tip_x = wrist_pt[0] + (np.cos(total_angle) * total_hand_len)
            tip_y = wrist_pt[1] + (np.sin(total_angle) * total_hand_len)
            tip_int = (int(tip_x), int(tip_y))

            cv2.line(canvas, wrist_int, knuckle_int, colors[i], 2)
            cv2.line(canvas, knuckle_int, tip_int, colors[i], 4)
            cv2.circle(canvas, knuckle_int, 4, colors[i], -1)
            cv2.circle(canvas, tip_int, 3, colors[i], -1)

        return canvas

    def _extract_and_warp(self, img, mask, p_s_old, p_e_old, p_s_new, p_e_new, thick, extend_end=False):
        seg_mask = np.zeros(img.shape[:2], dtype=np.uint8)
        p_draw_end = p_e_old
        if extend_end:
            p_draw_end = GeometryHelper.get_extended_point(p_s_old, p_e_old, factor=0.45)

        cv2.line(seg_mask, (int(p_s_old[0]), int(p_s_old[1])), (int(p_draw_end[0]), int(p_draw_end[1])), 255, int(thick))
        cv2.circle(seg_mask, (int(p_s_old[0]), int(p_s_old[1])), int(thick/1.0), 255, -1)
        if not extend_end:
            cv2.circle(seg_mask, (int(p_e_old[0]), int(p_e_old[1])), int(thick/1.8), 255, -1)

        combined_mask = cv2.bitwise_and(seg_mask, mask)
        texture = cv2.bitwise_and(img, img, mask=combined_mask)
        b, g, r = cv2.split(texture)
        rgba = cv2.merge([b, g, r, combined_mask])

        angle_old = GeometryHelper.get_angle(p_s_old, p_e_old)
        angle_new = GeometryHelper.get_angle(p_s_new, p_e_new)
        angle_diff = angle_old - angle_new

        pivot_x = p_s_old[0]
        pivot_y = p_s_old[1]
        M = cv2.getRotationMatrix2D((int(pivot_x), int(pivot_y)), angle_diff, 1.0)
        M[0, 2] += (p_s_new[0] - pivot_x)
        M[1, 2] += (p_s_new[1] - pivot_y)

        return cv2.warpAffine(rgba, M, (img.shape[1], img.shape[0]), flags=cv2.INTER_LINEAR)
    
    def map_coords_to_model_space(self, x, y, orig_w, orig_h, target_size=512):
        # 1. Determine the square dimension
        max_dim = max(orig_w, orig_h)
        # 2. Calculate the Padding (Offset)
        pad_x = (max_dim - orig_w) // 2
        pad_y = (max_dim - orig_h) // 2
        # 3. Apply Padding
        x_padded = x + pad_x
        y_padded = y + pad_y
        # 4. Calculate Scale Factor
        scale = target_size / max_dim
        # 5. Apply Scaling
        x_new = x_padded * scale
        y_new = y_padded * scale
        return x_new, y_new

    def process_request(self, image_input, offset_config):
        HIP_SCALE = 1.0
        try:
            RIGHT_WRIST = tuple(offset_config[0])
            RIGHT_ELBOW = tuple(offset_config[1])
            LEFT_WRIST = tuple(offset_config[2])
            LEFT_ELBOW = tuple(offset_config[3])
            RIGHT_HIP = tuple(offset_config[4])
            LEFT_HIP = tuple(offset_config[5])
        except (IndexError, ValueError) as e:
            raise ValueError("Invalid offset_config format. Expected list of length 7.") from e

        # Load Image
        if isinstance(image_input, (bytes, bytearray)):
            raw_image = Image.open(BytesIO(image_input)).convert("RGB")
        else:
            raise TypeError("image_input must be bytes")
        
        orig_w, orig_h = raw_image.size

        RIGHT_WRIST = self.map_coords_to_model_space(RIGHT_WRIST[0], RIGHT_WRIST[1], orig_w, orig_h)
        RIGHT_ELBOW = self.map_coords_to_model_space(RIGHT_ELBOW[0], RIGHT_ELBOW[1], orig_w, orig_h)
        LEFT_WRIST = self.map_coords_to_model_space(LEFT_WRIST[0], LEFT_WRIST[1], orig_w, orig_h)
        LEFT_ELBOW = self.map_coords_to_model_space(LEFT_ELBOW[0], LEFT_ELBOW[1], orig_w, orig_h)
        RIGHT_HIP = self.map_coords_to_model_space(RIGHT_HIP[0], RIGHT_HIP[1], orig_w, orig_h)
        LEFT_HIP = self.map_coords_to_model_space(LEFT_HIP[0], LEFT_HIP[1], orig_w, orig_h)

        original_image = self._make_square(raw_image, 512)
        src_np = np.array(original_image)
        
        # --- 2. Pose Detection (USING MOVENET) ---
        raw_kps, shape = self.pose_helper.process_image(original_image)
        kps_old = self.pose_helper.get_coco_keypoints(raw_kps, shape)

        def axis_zero(diff):
            return 0 if abs(diff) < 2 else diff

        # RIGHT WRIST
        dx = RIGHT_WRIST[0] - kps_old[10][0]
        dy = RIGHT_WRIST[1] - kps_old[10][1]
        RIGHT_WRIST_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Right wrist offset: ", RIGHT_WRIST_OFFSET)
        # RIGHT ELBOW
        dx = RIGHT_ELBOW[0] - kps_old[8][0]
        dy = RIGHT_ELBOW[1] - kps_old[8][1]
        RIGHT_ELBOW_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Right Elbow offset: ", RIGHT_ELBOW_OFFSET)

        # LEFT WRIST
        dx = LEFT_WRIST[0] - kps_old[9][0]
        dy = LEFT_WRIST[1] - kps_old[9][1]
        LEFT_WRIST_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Left wrist offset: ", LEFT_WRIST_OFFSET)
        # LEFT ELBOW
        dx = LEFT_ELBOW[0] - kps_old[7][0]
        dy = LEFT_ELBOW[1] - kps_old[7][1]
        LEFT_ELBOW_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Left wrist offset: ", LEFT_WRIST_OFFSET)
        # RIGHT HIP
        dx = RIGHT_HIP[0] - kps_old[12][0]
        dy = RIGHT_HIP[1] - kps_old[12][1]
        RIGHT_HIP_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Right hip offset: ", RIGHT_HIP_OFFSET)
        # LEFT HIP
        dx = LEFT_HIP[0] - kps_old[11][0]
        dy = LEFT_HIP[1] - kps_old[11][1]
        LEFT_HIP_OFFSET = (axis_zero(dx), axis_zero(dy))
        print("Left hip offset: ", LEFT_HIP_OFFSET)
        # --- 3. Segmentation ---
        person_mask = self._get_person_mask(src_np, kps_old)
        
        # --- 4. Modify Skeleton ---
        kps_new = kps_old.copy()
        redraw_right_hand = False
        redraw_left_hand = False

        # Apply Arm Offsets
        if RIGHT_WRIST_OFFSET != (0, 0):
            kps_new[10][0] += RIGHT_WRIST_OFFSET[0]
            kps_new[10][1] += RIGHT_WRIST_OFFSET[1]
            redraw_right_hand = True

        if RIGHT_ELBOW_OFFSET != (0, 0):
            kps_new[8][0] += RIGHT_ELBOW_OFFSET[0]
            kps_new[8][1] += RIGHT_ELBOW_OFFSET[1]

        if LEFT_WRIST_OFFSET != (0, 0):
            kps_new[9][0] += LEFT_WRIST_OFFSET[0]
            kps_new[9][1] += LEFT_WRIST_OFFSET[1]
            redraw_left_hand = True

        if LEFT_ELBOW_OFFSET != (0, 0):
            kps_new[7][0] += LEFT_ELBOW_OFFSET[0]
            kps_new[7][1] += LEFT_ELBOW_OFFSET[1]
            
        # Calc Dynamic Hip Scale if offsets provided
        if (LEFT_HIP_OFFSET!=(0,0) or RIGHT_HIP_OFFSET!=(0,0)):
            # Avoid division by zero
            hip_width = kps_old[12][0] - kps_old[11][0]
            if abs(hip_width) > 1e-5:
                HIP_SCALE = 1 + (RIGHT_HIP_OFFSET[0] - LEFT_HIP_OFFSET[0])/ hip_width

        # Apply Hip Scaling
        if HIP_SCALE != 1.0:
            L_hip = np.array(kps_old[11])
            R_hip = np.array(kps_old[12])
            mid = (L_hip + R_hip) / 2
            kps_new[11] = mid + (L_hip - mid) * HIP_SCALE
            kps_new[12] = mid + (R_hip - mid) * HIP_SCALE

        # Draw New Skeleton
        viz_skel_new = self.pose_helper.draw_skeleton(kps_new, shape)
        
        # Inject Synthetic Hands
        if redraw_right_hand:
            viz_skel_new = self._draw_synthetic_hand(viz_skel_new, kps_new[8][:2], kps_new[10][:2], scale_factor=1.1)
        if redraw_left_hand:
            viz_skel_new = self._draw_synthetic_hand(viz_skel_new, kps_new[7][:2], kps_new[9][:2], scale_factor=1.1)

        # --- 5. Prepare Masks & Warps ---
        input_ai_composition = src_np.copy()
        final_inpaint_mask = np.zeros(shape[:2], dtype=np.uint8)
        
        l_sh = kps_old[5][:2]; r_sh = kps_old[6][:2]
        limb_thick = int(np.linalg.norm(l_sh - r_sh) * 0.25)
        
        mask_warped_pixels = np.zeros(shape[:2], dtype=np.uint8)
        canvas_warped = np.full_like(src_np, 255)

        # Handle Arms
        if (redraw_right_hand or RIGHT_ELBOW_OFFSET != (0, 0)):
            w_up_R = self._extract_and_warp(src_np, person_mask, kps_old[6], kps_old[8], kps_new[6], kps_new[8], limb_thick, False)
            w_lo_R = self._extract_and_warp(src_np, person_mask, kps_old[8], kps_old[10], kps_new[8], kps_new[10], limb_thick, True)
            for layer in [w_up_R, w_lo_R]:
                m = layer[:,:,3] > 0
                canvas_warped[m] = layer[m, :3]
                mask_warped_pixels[m] = 255
                
        if (redraw_left_hand or LEFT_ELBOW_OFFSET != (0, 0)):
            w_up_L = self._extract_and_warp(src_np, person_mask, kps_old[5], kps_old[7], kps_new[5], kps_new[7], limb_thick, False)
            w_lo_L = self._extract_and_warp(src_np, person_mask, kps_old[7], kps_old[9], kps_new[7], kps_new[9], limb_thick, True)
            for layer in [w_up_L, w_lo_L]:
                m = layer[:,:,3] > 0
                canvas_warped[m] = layer[m, :3]
                mask_warped_pixels[m] = 255

        # Erase Old Arms
        mask_old_arm_area = np.zeros(shape[:2], dtype=np.uint8)
        if (redraw_right_hand or RIGHT_ELBOW_OFFSET != (0, 0)):
            tip = GeometryHelper.get_extended_point(kps_old[8], kps_old[10], 0.5)
            cv2.line(mask_old_arm_area, (int(kps_old[6][0]), int(kps_old[6][1])), (int(kps_old[8][0]), int(kps_old[8][1])), 255, int(limb_thick*1.4))
            cv2.line(mask_old_arm_area, (int(kps_old[8][0]), int(kps_old[8][1])), (int(tip[0]), int(tip[1])), 255, int(limb_thick*1.4))

        if (redraw_left_hand or LEFT_ELBOW_OFFSET != (0, 0)):
            tip = GeometryHelper.get_extended_point(kps_old[7], kps_old[9], 0.5)
            cv2.line(mask_old_arm_area, (int(kps_old[5][0]), int(kps_old[5][1])), (int(kps_old[7][0]), int(kps_old[7][1])), 255, int(limb_thick*1.4))
            cv2.line(mask_old_arm_area, (int(kps_old[7][0]), int(kps_old[7][1])), (int(tip[0]), int(tip[1])), 255, int(limb_thick*1.4))

        # Background Fill
        safe_bg_mask = cv2.dilate(person_mask, np.ones((5,5), np.uint8), iterations=2)
        bg_mask = cv2.bitwise_not(safe_bg_mask)
        if np.count_nonzero(bg_mask) > 0:
            bg_pixels = src_np[bg_mask > 0]
            bg_color = np.median(bg_pixels, axis=0).astype(int).tolist()
        else:
            bg_color = src_np[5, 5].tolist()

        input_ai_composition[mask_old_arm_area > 0] = bg_color
        input_ai_composition[mask_warped_pixels > 0] = canvas_warped[mask_warped_pixels > 0]
        final_inpaint_mask = cv2.bitwise_or(final_inpaint_mask, mask_old_arm_area)
        final_inpaint_mask = cv2.bitwise_or(final_inpaint_mask, mask_warped_pixels)

        # Handle Hip Masking
        if HIP_SCALE != 1.0:
            lats_mask = np.zeros(shape[:2], dtype=np.uint8)
            def xy(pt): return (int(pt[0]), int(pt[1]))
            
            L_rib   = (kps_old[5][:2] * 0.6 + kps_old[11][:2] * 0.4).astype(int)
            R_rib   = (kps_old[6][:2] * 0.6 + kps_old[12][:2] * 0.4).astype(int)
            L_waist = ((L_rib + kps_old[11][:2]) / 2).astype(int)
            R_waist = ((R_rib + kps_old[12][:2]) / 2).astype(int)
            L_hip   = kps_old[11][:2].astype(int)
            R_hip   = kps_old[12][:2].astype(int)
            torso_thick = int(limb_thick * 1.4)

            cv2.line(lats_mask, xy(L_rib), xy(L_waist), 255, torso_thick)
            cv2.line(lats_mask, xy(L_waist), xy(L_hip), 255, torso_thick)
            cv2.circle(lats_mask, xy(L_rib), torso_thick//2, 255, -1)
            cv2.circle(lats_mask, xy(L_waist), torso_thick//2, 255, -1)
            cv2.circle(lats_mask, xy(L_hip), torso_thick//2, 255, -1)

            cv2.line(lats_mask, xy(R_rib), xy(R_waist), 255, torso_thick)
            cv2.line(lats_mask, xy(R_waist), xy(R_hip), 255, torso_thick)
            cv2.circle(lats_mask, xy(R_rib), torso_thick//2, 255, -1)
            cv2.circle(lats_mask, xy(R_waist), torso_thick//2, 255, -1)
            cv2.circle(lats_mask, xy(R_hip), torso_thick//2, 255, -1)

            lats_mask = cv2.bitwise_and(lats_mask, person_mask)
            lats_mask = cv2.dilate(lats_mask, np.ones((9,9), np.uint8), iterations=1)
            final_inpaint_mask = cv2.bitwise_or(final_inpaint_mask, lats_mask)

        final_inpaint_mask = cv2.dilate(final_inpaint_mask, np.ones((10,10), np.uint8), iterations=2)

        # --- 6. Generation ---
        control_map_img = Image.fromarray(viz_skel_new)
        # Fix BGR to RGB for control image
        r, g, b = control_map_img.split()
        control_map_img = Image.merge("RGB", (b, g, r))

        prompt_str = ""
        if HIP_SCALE < 1.0:
            prompt_str += ", flat stomach, slim waist"

        generated_raw = self.pipe(
            prompt=prompt_str,
            negative_prompt="clothing, fabric, blue cloth, sleeve, deformed, extra limb, grey blob, cartoon, warped hand, blur, noise",
            image=Image.fromarray(input_ai_composition),
            mask_image=Image.fromarray(final_inpaint_mask),
            control_image=control_map_img,
            num_inference_steps=30,
            strength=0.87,
            controlnet_conditioning_scale=1.5
        ).images[0]

        # Composite Result
        gen_np = np.array(generated_raw)
        mask_blur = cv2.GaussianBlur(final_inpaint_mask, (21, 21), 0)
        alpha = mask_blur.astype(float) / 255.0
        alpha = np.stack([alpha]*3, axis=2)
        composite = (gen_np * alpha) + (src_np * (1.0 - alpha))
        
        composite_img = Image.fromarray(composite.astype(np.uint8))
        
        restored_img = self._restore_original_dimensions(
            composite_img,   
            orig_w,          
            orig_h           
        )

        return restored_img