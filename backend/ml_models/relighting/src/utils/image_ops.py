#functions to handle image and environment map processing/manipulation

import os
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
import numpy as np
import cv2
from PIL import Image
import torch
import imageio
from numba import njit
from config import cfg
import matplotlib.pyplot as plt
import json


def preprocess_object(pil_img: Image.Image, mask: np.ndarray, target_res=256, bg_value=1.0) -> Image.Image:
    """
    Preprocess the image so that only the masked object is visible.
    Background pixels are replaced with a solid color (default white),
    the entire image is resized to the target resolution, by padding and resizing.

    Args:
        #TODO
    """
    #reading, and normalizing the image
    img = np.array(pil_img).astype(np. float32) / 255.0
    m = (mask > 0).astype(np.float32)[..., None]  


    #replace background color
    bg = np.ones_like(img) * bg_value
    obj_only = img * m + bg * (1.0 - m)
    obj_only = np.clip(obj_only * 255.0, 0, 255).astype(np.uint8)


    #padding andresizing
    h, w = obj_only.shape[:2]
    max_dim = max(h, w)
    square_img = np.ones((max_dim, max_dim, 3), dtype=np.uint8) * int(bg_value * 255)
    #placing the obj in center of img
    top = (max_dim - h) // 2
    left = (max_dim - w) // 2
    square_img[top:top+h, left:left+w] = obj_only
    #resizing
    obj_only_resized = cv2.resize(square_img, (target_res, target_res), interpolation=cv2.INTER_AREA)

    #metadata, to assist recomposition after relighting
    meta = {
        "orig_h": h,
        "orig_w": w,
        "pad_top": top,
        "pad_left": left,
        "max_dim": max_dim,
        "target_res": target_res
    }

    return Image.fromarray(obj_only_resized), meta


# def upscale_relit(relit_pil: Image.Image, scale_factor: float = 1.0, target_res: int = None, resample=Image.LANCZOS, upscaler_callback=None) -> Image.Image:
#     """
#     Upscale the relit object image in a modular way.

#     - If `upscaler_callback` is provided it will be called as
#       `upscaler_callback(relit_pil, scale_factor=scale_factor, target_res=target_res)`
#       and its return value will be used (enables integration with Real-ESRGAN or other models).
#     - Otherwise, a simple PIL resize is used. If `target_res` is provided it overrides
#       `scale_factor` and the image will be resized to `(target_res, target_res)`.

#     Args:
#         relit_pil: PIL image produced by the relighting pipeline.
#         scale_factor: Multiplicative upscale factor (1.0 = no-op).
#         target_res: Exact square resolution to resize to (optional).
#         resample: PIL resampling filter to use for simple resize.
#         upscaler_callback: Optional callable for custom upscaling.

#     Returns:
#         PIL.Image: Upscaled image.
#     """
#     # If user provided a custom upscaler, delegate to it (keeps modularity)
#     if upscaler_callback is not None:
#         return upscaler_callback(relit_pil, scale_factor=scale_factor, target_res=target_res)

#     if target_res is not None:
#         w = h = int(target_res)
#     else:
#         if scale_factor is None or float(scale_factor) <= 1.0:
#             return relit_pil
#         w, h = relit_pil.size
#         w = int(round(w * float(scale_factor)))
#         h = int(round(h * float(scale_factor)))

#     return relit_pil.resize((w, h), resample=resample)


def read_hdri_map(hdri_path, target_res=(256, 256), rot_angle=0.0):
    """
    Process the HDRI to create two representations:
    - First: HDR representation (log-mapped)
    - Second: LDR representation (gamma-corrected)
    Both are normalized to [-1, 1].
    Returned as tensors with shape [1, 3, H, W].

    Args:
        hdri_path (str): Path to the HDR environment map (.exr)
        target_res (tuple): Output resolution (H, W)
        rot_angle (float): Rotation angle in degrees.
    """
    hdri = cv2.imread(hdri_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)

    #if cv2 fails to read the hdri, fall back to imageio
    if hdri is None:
        hdri = imageio.imread(hdri_path)
    else:
        hdri = cv2.cvtColor(hdri, cv2.COLOR_BGR2RGB)


    hdri = cv2.resize(hdri, target_res, interpolation=cv2.INTER_AREA).astype(np.float32)

    #rotating the hdri (azimuthal rotation)
    if rot_angle != 0:
        W = hdri.shape[1]
        shift = int((rot_angle / 360.0) * W)
        hdri = np.roll(hdri, shift=shift, axis=1)

    #HDR-part 
    hdr = np.log1p(10.0 * np.maximum(hdri, 0))
    mx = float(np.max(hdr))
    if mx > 0:
        hdr = hdr / mx
    hdr = np.clip(hdr, 0, 1)

    #LDR-part
    ldr = np.clip(hdri, 0, 1) ** (1/2.2)

    #normalize
    ldr = ldr * 2.0 - 1.0


    hdr_t = torch.from_numpy(hdr).permute(2, 0, 1).unsqueeze(0).float()
    ldr_t = torch.from_numpy(ldr).permute(2, 0, 1).unsqueeze(0).float()

    return hdr_t, ldr_t



def get_light_direction_from_hdr(env_torch):
    """
    Extracts the main light direction (azimuth, altitude) from a HDRI (tensor format).
    Args:
        env_torch: env map as a torch tensor of shape [1, 3, H, W] with values in [-1, 1].
        applied_rot_angle (float): rotation angle applied.
    
    Returns:
        (azimuth_deg, altitude_deg)
    """

    env_np = env_torch.squeeze(0).permute(1, 2, 0).cpu().numpy()
    env_np = (env_np + 1.0) / 2.0 

    #luminiscence, we are using ITU-R BT.709 standard
    lum = 0.2126*env_np[:,:,0] + 0.7152*env_np[:,:,1] + 0.0722*env_np[:,:,2]

    #finding location of brightest spot
    _, _, _, max_loc = cv2.minMaxLoc(lum)
    bright_x, bright_y = max_loc
    h, w = lum.shape
    azimuth = (bright_x / w) * 360.0
    altitude = ((h - bright_y) / h) * 180.0 - 90.0

    final_azimuth  = azimuth % 360.0
    final_altitude = max(10.0, altitude)

    return final_azimuth, final_altitude

def estimate_light_source_strength(env_torch):
    """
    Estimates how strong and directional the main light is in an HDRI.
    Returns a value between 0 (cloudy) and 1 (direct sunlight).
    This determines the shadow's intensity.
    """
    
    env_np = env_torch.squeeze(0).permute(1, 2, 0).cpu().numpy()
    env_np = (env_np + 1.0) / 2.0

    #luminance
    lum = 0.2126 * env_np[:, :, 0] + 0.7152 * env_np[:, :, 1] + 0.0722 * env_np[:, :, 2]

    mean_lum = np.mean(lum)
    max_lum = np.max(lum)
    std_lum = np.std(lum)


    contrast = (max_lum - mean_lum) / (mean_lum + 1e-6)
    directionality = contrast * (std_lum * 5.0)
    shadow_strength = float(np.clip(directionality, 0.0, 1.0))

    return shadow_strength


def composite_with_shadows(depth_estimator, original_pil, relit_pil, mask, meta, hdri_path, rot_angle, shadow_reach=0.4, debug=False):
    """
    Composites the relit object back into the original scene.
    
    Args:
        depth_estimator: Model for extracting background and object depth.
        original_pil (Image.Image): Original background image.
        relit_pil (Image.Image): Relit object image at target resolution.
        mask (np.ndarray): Binary segmentation mask of the object.
        meta (dict): Preprocessing metadata containing original dimensions and padding info
                     (keys: 'orig_h', 'orig_w', 'pad_top', 'pad_left', 'max_dim', 'target_res').
        hdri_path (str): Path to the HDRI environment map (.exr) used for lighting analysis.
        rot_angle (float): Rotation angle applied to the HDRI in degrees.
        shadow_reach (float, optional): Maximum shadow distance as fraction of image dimension. Default: 0.4.
        debug (bool, optional): If True, displays visualization of shadow layers. Default: False.
    
    Returns:
        Image.Image: Final composited image with relit object and shadows on original background.
    """

    #setup
    h_orig, w_orig = meta["orig_h"], meta["orig_w"]
    top, left = meta["pad_top"], meta["pad_left"]
    max_dim = meta["max_dim"]

    original_np = np.array(original_pil)
    relit_np = np.array(relit_pil).astype(np.float32) / 255.0
    relit_square = cv2.resize(relit_np, (max_dim, max_dim), interpolation=cv2.INTER_LANCZOS4)
    relit_crop = relit_square[top:top + h_orig, left:left + w_orig]

    mask_full = mask.astype(np.uint8)
    if mask_full.shape != (h_orig, w_orig):
        mask_full = cv2.resize(mask_full, (w_orig, h_orig), interpolation=cv2.INTER_NEAREST)
    mask_bin = (mask_full > 0.5).astype(np.uint8)

    #estimating depth and light
    bg_depth_pil = depth_estimator(original_pil)["depth"]
    bg_depth = np.array(bg_depth_pil.resize((w_orig, h_orig))).astype(np.float32) / 255.0
    obj_depth = np.clip(bg_depth - (mask_bin * 0.02), 0.0, 1.0)

    first_target_envir_map, second_target_envir_map = read_hdri_map(
        hdri_path, target_res=(cfg.TARGET_RES, cfg.TARGET_RES), rot_angle=rot_angle
    )
    # az, alt = get_light_direction_from_hdr(second_target_envir_map, applied_rot_angle=rot_angle)
    az, alt = get_light_direction_from_hdr(second_target_envir_map)

    #shadow strength
    light_source_strength = estimate_light_source_strength(second_target_envir_map)
    light_source_strength *= max(0.0, 1.0 - (alt / 85.0))

    if light_source_strength < 0.05: light_source_strength = 0.05 #to keep the image from being completely dark

    #Raymarch shadow
    bg_height = 1.0 - bg_depth
    obj_height = 1.0 - obj_depth

    raw_shadow = raymarch_shadows(bg_height, obj_height, mask_bin, az, alt)

    #fade the shadows with distance
    inv_mask = (1.0 - mask_bin).astype(np.uint8)
    dist_map = cv2.distanceTransform(inv_mask, cv2.DIST_L2, 5)
    max_dist_px = int(max(h_orig, w_orig) * shadow_reach)
    fade_mask = np.clip(1.0 - (dist_map / max_dist_px), 0.0, 1.0) ** 1.5

    directional_shadow = raw_shadow * (1.0 - mask_bin) * fade_mask
    directional_shadow = cv2.GaussianBlur(directional_shadow, (0, 0), sigmaX=8.0)

    #control the shadow based on light source strength
    directional_shadow *= (0.8 * light_source_strength)

    #making shadow near the bottom part, where the object meets the surface
    #identifying the bottom part
    rows = np.any(mask_bin, axis=1)
    if np.any(rows):
        ymin, ymax = np.where(rows)[0][[0, -1]]
        h, w = mask_bin.shape
        yy, xx = np.mgrid[0:h, 0:w]
        # Linear gradient from ankle to floor
        feet_zone = (yy - (ymax - (ymax-ymin)*0.20)) / ((ymax-ymin)*0.20)
        feet_zone = np.clip(feet_zone, 0.0, 1.0)
    else:
        feet_zone = np.zeros_like(mask_bin)

    
    #erode and blurring the mask to create smooth contact area
    kernel = np.ones((3,3), np.uint8)
    eroded_mask = cv2.erode(mask_bin, kernel, iterations=1)
    eroded_mask = cv2.GaussianBlur(eroded_mask, (7, 7), 0)
    eroded_mask = Image.fromarray(eroded_mask)

    shifted_mask = np.roll(eroded_mask, 4, axis=0)

    contact_blob = shifted_mask * (1.0 - mask_bin) * feet_zone
    contact_shadow = cv2.GaussianBlur(contact_blob, (0,0), sigmaX=6.0)
    contact_shadow *= 0.5
    
    #combining the different shadow layers
    final_shadow_map = np.maximum(directional_shadow, contact_shadow)

    if debug:
        plt.figure(figsize=(12, 4))
        plt.subplot(1, 3, 1); plt.imshow(directional_shadow, cmap='gray', vmin=0, vmax=1); plt.title("Directional (Variable)")
        plt.subplot(1, 3, 2); plt.imshow(contact_shadow, cmap='gray', vmin=0, vmax=1); plt.title("Contact (Forced Dark)")
        plt.subplot(1, 3, 3); plt.imshow(final_shadow_map, cmap='gray', vmin=0, vmax=1); plt.title("Final Merged")
        plt.show()

    #compositing the final image
    shadow_layer = 1.0 - final_shadow_map
    comp = original_np.astype(np.float32) / 255.0
    for c in range(3):
        comp[:, :, c] *= shadow_layer

    mask_3ch = mask_full[..., None]
    comp = relit_crop * mask_3ch + comp * (1.0 - mask_3ch)

    return Image.fromarray(np.clip(comp * 255.0, 0, 255).astype(np.uint8))


def draw_geometry(img_canvas, geometry, width, height, color_bgr, opacity=1.0, extra_thickness=0):
    """
    Helper to draw primitives (Lines or Circles) onto a canvas, for environment map generation.
    It is an inplace operation
    """
    # Handle both object attributes and dictionary access
    if hasattr(geometry, 'type'):
        geo_type = geometry.type
    elif isinstance(geometry, dict):
        geo_type = geometry.get('type')
    else:
        return  # Skip if neither object nor dict

    if geo_type == "LineString":
        if hasattr(geometry, 'coordinates'):
            coords = geometry.coordinates
        elif isinstance(geometry, dict):
            coords = geometry['coordinates']
        else:
            return
        pts = np.array([[int(p[0] * width), int(p[1] * height)] for p in coords], np.int32)
        pts = pts.reshape((-1, 1, 2))

        #line
        thickness = 10 + extra_thickness
        cv2.polylines(img_canvas, [pts], isClosed=False, color=color_bgr, thickness=thickness)

    elif geo_type == "SingleLightSource":
        if hasattr(geometry, 'center'):
            c = geometry.center
            raw_radius = geometry.radius if hasattr(geometry, 'radius') else 5
        elif isinstance(geometry, dict):
            c = geometry['center']
            raw_radius = geometry.get('radius', 5)
        else:
            return
        cx, cy = int(c[0] * width), int(c[1] * height)

        #scaling factor : hyperparmeter
        radius = int(raw_radius * 5) + extra_thickness

        #circle
        cv2.circle(img_canvas, (cx, cy), radius, color_bgr, -1)


def render_multi_light_layer(width, height, lights_list):
    """
    Renders complex multi-light setup with 'Core' (White) and 'Glow' (Colored) passes.
    """

    glow_layer = np.zeros((height, width, 3), dtype=np.float32)
    core_layer = np.zeros((height, width, 3), dtype=np.float32)

    for light in lights_list:
        # Handle both object attributes and dictionary access
        if hasattr(light, 'properties'):
            props = light.properties
            geom = light.geometry
        elif isinstance(light, dict):
            props = light.get('properties', {})
            geom = light.get('geometry', {})
        else:
            continue

        #determine the color
        if hasattr(props, 'color'):
            color_value = props.color
        elif isinstance(props, dict):
            color_value = props.get('color', (1.0, 1.0, 1.0))
        else:
            color_value = (1.0, 1.0, 1.0)

        if isinstance(color_value, str):
            # Handle hex color codes
            if color_value.startswith('#'):
                hex_color = color_value.lstrip('#')
                r = int(hex_color[0:2], 16) / 255.0
                g = int(hex_color[2:4], 16) / 255.0
                b = int(hex_color[4:6], 16) / 255.0
            else:
                # Handle named colors
                COLOR_MAP = {
                    "red": (1.0, 0.0, 0.0),
                    "green": (0.0, 1.0, 0.0),
                    "blue": (0.0, 0.0, 1.0),
                    "white": (1.0, 1.0, 1.0),
                    "orange": (1.0, 0.5, 0.0),
                    "yellow": (1.0, 1.0, 0.0),
                    "purple": (0.5, 0.0, 0.5)
                }
                r, g, b = COLOR_MAP.get(color_value.lower(), (1.0, 1.0, 1.0))
        else:
            r, g, b = color_value

        #boosting the saturation for the glow-layer
        glow_r, glow_g, glow_b = r**2.0, g**2.0, b**2.0

        glow_color_bgr = (glow_b, glow_g, glow_r)
        tint_strength = 0.3  # adjust between 0.2–0.4 for subtle tint
        core_r = (1.0 * (1 - tint_strength)) + (r * tint_strength)
        core_g = (1.0 * (1 - tint_strength)) + (g * tint_strength)
        core_b = (1.0 * (1 - tint_strength)) + (b * tint_strength)

        core_color_bgr = (core_b, core_g, core_r)

        #drawing the glow part
        temp_glow = np.zeros((height, width, 3), dtype=np.float32)
        draw_geometry(temp_glow, geom, width, height, glow_color_bgr, extra_thickness=40)
        
        #applying a blur
        temp_glow = cv2.GaussianBlur(temp_glow, (101, 101), 0)
        glow_layer += temp_glow * 30.0

        #drawing the core
        temp_core = np.zeros((height, width, 3), dtype=np.float32)
        draw_geometry(temp_core, geom, width, height, core_color_bgr, extra_thickness=0)
        
        #blurring
        temp_core = cv2.GaussianBlur(temp_core, (21, 21), 0)
        core_layer += temp_core * 80.0 # High Intensity

    #combining
    total_light = glow_layer + core_layer
    return total_light


def generate_env_map_from_image(pil_img, pil_mask, lights_config=None, metadata_path=None, exr_folder=None, output_path=None):
    """
    Generates a custom environment map by finding a matching base map and adding custom lights.
    
    Args:
        pil_img: Input image
        pil_mask: Segmentation mask
        lights_config: List of light configurations (optional)
        metadata_path: Path to environment map metadata JSON
        exr_folder: Folder containing base .exr files
        output_path: Where to save the generated .exr (optional)
    
    Returns:
        Path to the generated environment map
    """
    
    
    #config
    if metadata_path is None:
        metadata_path = cfg.ENV_MAP_METADATA_PATH
    if exr_folder is None:
        exr_folder = cfg.ENV_MAP_EXR_FOLDER
    if output_path is None:
        output_path = "./generated_env_map.exr"
    
    #analyzing bg color
    img_arr = np.array(pil_img)
    mask_arr = np.array(pil_mask)
    if mask_arr.max() <= 1:
        mask_arr = (mask_arr * 255).astype(np.uint8)
    if len(mask_arr.shape) > 2:
        mask_arr = mask_arr[:, :, 0]
    
    bg_mask = cv2.bitwise_not(mask_arr)
    mean_color = cv2.mean(img_arr, mask=bg_mask)[:3]
    user_bg_rgb = [mean_color[0], mean_color[1], mean_color[2]]
    
    #finding the best matching env map
    with open(metadata_path, 'r') as f:
        metadata_db = json.load(f)
    
    best_match = None
    min_dist = float('inf')
    for item in metadata_db:
        dist = np.sqrt(sum((c1 - c2)**2 for c1, c2 in zip(user_bg_rgb, item['ambient_rgb'])))
        if dist < min_dist:
            min_dist = dist
            best_match = item
    
    
    #loading the base map
    full_path = os.path.join(exr_folder, best_match['id'])
    env_map = cv2.imread(full_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)
    h, w, c = env_map.shape
    
    #adding lights according to user input
    if lights_config:
        light_layer = render_multi_light_layer(w, h, lights_config)
        env_map = env_map + light_layer
    

    cv2.imwrite(output_path, env_map)
    
    return output_path


@njit(fastmath=True)
def raymarch_shadows(bg_depth, obj_depth, obj_mask, az_deg, alt_deg):
    """
    Raymarcher shadow generation logic.
    """

    rows, cols = bg_depth.shape
    shadow_map = np.zeros((rows, cols), dtype=np.float32)

    
    az_rad = np.deg2rad(az_deg)
    alt_rad = np.deg2rad(alt_deg)

    #light vector
    dx = -np.sin(az_rad)
    dy = np.cos(az_rad)

    if dy > 0.0:
        return shadow_map

    #normalizing (to pixel scale)
    norm = np.sqrt(dx*dx + dy*dy) + 1e-6
    dx /= norm
    dy /= norm

    shadow_length = 150.0 / max(np.tan(alt_rad), 0.2)

    step_size = 1.0
    decay_rate = 0.01
    depth_threshold = 0.02

    for r in range(rows):
        for c in range(cols):
            if obj_mask[r, c] < 0.5:
                continue

            obj_d = obj_depth[r, c]
            bg_d = bg_depth[r, c]

            #skips the part behind objects
            if obj_d < bg_d:
                continue

            #move away from the light direction
            for t in np.arange(0, shadow_length, step_size):
                rr = int(r + dy * t)
                cc = int(c + dx * t)

                if rr < 0 or rr >= rows or cc < 0 or cc >= cols:
                    break
                
                #make sure no self shadow is cast
                if obj_mask[rr, cc] > 0.5:
                    continue

                target_bg_d = bg_depth[rr, cc]
                
                if target_bg_d <= obj_d + depth_threshold:
                    strength = np.exp(-decay_rate * t)
                    if strength > shadow_map[rr, cc]:
                        shadow_map[rr, cc] = strength

    #normalizing
    for r in range(rows):
        for c in range(cols):
            shadow_map[r, c] = min(1.0, shadow_map[r, c])

    return shadow_map
