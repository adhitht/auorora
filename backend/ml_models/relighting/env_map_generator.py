"""
Environment Map Generator
Generates custom environment maps based on user input and background analysis.
"""

import os
import cv2
import numpy as np
import json
from typing import Optional, Dict, List, Tuple
from PIL import Image


class EnvMapGenerator:
    """
    Generates environment maps by analyzing background colors and rendering custom lights.
    """
    
    def __init__(
        self, 
        metadata_path: str = "./content/envmapsmetadata.json",
        exr_folder: str = "./content/",
        light_source_threshold: float = 20.0
    ):
        """
        Initialize the environment map generator.
        
        Args:
            metadata_path: Path to the JSON file containing environment map metadata
            exr_folder: Folder containing the .exr environment map files
            light_source_threshold: Threshold for determining if a map has a strong light source
        """
        self.metadata_path = metadata_path
        self.exr_folder = exr_folder
        self.light_source_threshold = light_source_threshold
        
    def get_luminance(self, img: np.ndarray) -> np.ndarray:
        """
        Calculate luminance of an RGB image.
        
        Args:
            img: RGB image as numpy array
            
        Returns:
            Luminance values as numpy array
        """
        return 0.114 * img[:, :, 0] + 0.587 * img[:, :, 1] + 0.299 * img[:, :, 2]
    
    def analyze_single_map(self, filename: str, base_path: str) -> Optional[Dict]:
        """
        Analyze a single environment map to extract lighting metadata.
        
        Args:
            filename: Name of the .exr file
            base_path: Base directory containing the file
            
        Returns:
            Dictionary containing metadata about the environment map
        """
        full_path = os.path.join(base_path, filename)
        
        if not os.path.exists(full_path):
            print(f"⚠️ Warning: {full_path} not found. Skipping.")
            return None
        
        # Load image
        img = cv2.imread(full_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)
        
        if img is None:
            print(f"❌ Error: Could not read {filename}. Is it a valid EXR?")
            return None
        
        h, w, c = img.shape
        
        # 1. Find Key Light
        lum = self.get_luminance(img)
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(lum)
        brightest_x, brightest_y = max_loc
        
        azimuth = ((brightest_x / w) - 0.5) * 360.0
        elevation = -((brightest_y / h) - 0.5) * 180.0
        
        # 2. Ambient Vibe
        cutoff = np.percentile(lum, 90)
        mask = lum < cutoff
        
        avg_b = np.mean(img[:, :, 0][mask])
        avg_g = np.mean(img[:, :, 1][mask])
        avg_r = np.mean(img[:, :, 2][mask])
        
        ambient_rgb = [float(avg_r), float(avg_g), float(avg_b)]
        
        # 3. Tagging
        if elevation > 45:
            position_tag = "top"
        elif elevation < -10:
            position_tag = "low"
        else:
            position_tag = "side"
        
        print(f"✅ Analyzed {filename} | Azimuth: {azimuth:.1f}° | Elev: {elevation:.1f}°")
        
        return {
            "id": filename,
            "light_azimuth": azimuth,
            "light_elevation": elevation,
            "max_intensity": float(max_val),
            "ambient_rgb": ambient_rgb,
            "position_tag": position_tag
        }
    
    def create_metadata_database(
        self, 
        base_path: str = "./content",
        file_indices: range = range(1, 10),
        output_json_name: str = "./content/envmapsmetadata.json"
    ) -> List[Dict]:
        """
        Create a metadata database for multiple environment maps.
        
        Args:
            base_path: Directory containing .exr files
            file_indices: Range of file indices to process
            output_json_name: Output path for the JSON metadata file
            
        Returns:
            List of metadata dictionaries
        """
        print(f"📂 Current Working Directory: {os.getcwd()}")
        print(f"👀 Files in {base_path}:")
        
        if os.path.exists(base_path):
            all_files = os.listdir(base_path)
            print(all_files[:15])  # Print first 15 files to check
        print("-" * 30)
        
        print(f"Starting analysis...\n")
        
        metadata_database = []
        
        for i in file_indices:
            fname = f"envmap{i}.exr"
            data = self.analyze_single_map(fname, base_path)
            if data:
                metadata_database.append(data)
        
        # Save to JSON
        os.makedirs(os.path.dirname(output_json_name), exist_ok=True)
        with open(output_json_name, 'w') as f:
            json.dump(metadata_database, f, indent=4)
        
        print(f"\n🎉 Success! Processed {len(metadata_database)} maps.")
        print(f"Metadata saved to: {output_json_name}")
        
        return metadata_database
    
    def draw_geometry(
        self,
        img_canvas: np.ndarray,
        geometry: Dict,
        width: int,
        height: int,
        color_bgr: Tuple[float, float, float],
        opacity: float = 1.0,
        extra_thickness: int = 0
    ) -> None:
        """
        Draw geometric primitives (lines or circles) onto a canvas.
        
        Args:
            img_canvas: Canvas to draw on
            geometry: Geometry specification dictionary
            width: Canvas width
            height: Canvas height
            color_bgr: Color in BGR format
            opacity: Opacity (not currently used)
            extra_thickness: Additional thickness for drawing
        """
        geo_type = geometry.get('type')
        
        if geo_type == "LineString":
            # Parse coordinates [[x,y], [x,y]]
            coords = geometry['coordinates']
            pts = np.array([[int(p[0] * width), int(p[1] * height)] for p in coords], np.int32)
            pts = pts.reshape((-1, 1, 2))
            
            # Draw Line
            thickness = 10 + extra_thickness
            cv2.polylines(img_canvas, [pts], isClosed=False, color=color_bgr, thickness=thickness)
        
        elif geo_type == "SingleLightSource":
            # Parse center [x,y]
            c = geometry['center']
            cx, cy = int(c[0] * width), int(c[1] * height)
            
            # Parse Radius (Assume input is small, scale it up for map resolution)
            # Scaling factor heuristic: 4 input -> ~20 pixels on a 1k map
            raw_radius = geometry.get('radius', 5)
            radius = int(raw_radius * 5) + extra_thickness
            
            # Draw Circle
            cv2.circle(img_canvas, (cx, cy), radius, color_bgr, -1)
    
    def render_multi_light_layer(
        self,
        width: int,
        height: int,
        lights_list: List[Dict]
    ) -> np.ndarray:
        """
        Render complex multi-light setup with 'Core' (White) and 'Glow' (Colored) passes.
        
        Args:
            width: Width of the environment map
            height: Height of the environment map
            lights_list: List of light specifications
            
        Returns:
            Rendered light layer as numpy array
        """
        # Initialize separate layers
        glow_layer = np.zeros((height, width, 3), dtype=np.float32)
        core_layer = np.zeros((height, width, 3), dtype=np.float32)
        
        for light in lights_list:
            props = light.get('properties', {})
            geom = light.get('geometry', {})
            
            # 1. Determine Color
            color_value = props.get('color', (1.0, 1.0, 1.0))
            
            if isinstance(color_value, str):
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
            
            # Boost saturation for the GLOW only (Power curve)
            # This makes the fade-out look deeply colored
            glow_r, glow_g, glow_b = r**2.0, g**2.0, b**2.0
            
            glow_color_bgr = (glow_b, glow_g, glow_r)  # Normalize
            core_color_bgr = (1.0, 1.0, 1.0)  # Pure white core
            
            # 2. Draw The GLOW (Large, Colored)
            # We draw onto a temp mask to apply specific blur
            temp_glow = np.zeros((height, width, 3), dtype=np.float32)
            self.draw_geometry(temp_glow, geom, width, height, glow_color_bgr, extra_thickness=40)
            # Large Blur
            temp_glow = cv2.GaussianBlur(temp_glow, (101, 101), 0)
            glow_layer += temp_glow * 30.0  # Medium Intensity
            
            # 3. Draw The CORE (Small, White)
            temp_core = np.zeros((height, width, 3), dtype=np.float32)
            self.draw_geometry(temp_core, geom, width, height, core_color_bgr, extra_thickness=0)
            # Small Blur
            temp_core = cv2.GaussianBlur(temp_core, (21, 21), 0)
            core_layer += temp_core * 80.0  # High Intensity
        
        # Combine: Base + Glow + Core
        total_light = glow_layer + core_layer
        return total_light
    
    def generate_targeted_env_map(
        self,
        pil_img: Image.Image,
        pil_mask: Image.Image,
        lights_json_path: Optional[str] = None,
        output_path: Optional[str] = None
    ) -> np.ndarray:
        """
        Generate a custom environment map based on background analysis and custom lights.
        
        Args:
            pil_img: Input PIL image
            pil_mask: Segmentation mask as PIL image
            lights_json_path: Path to JSON file containing light specifications
            output_path: Optional path to save the generated environment map
            
        Returns:
            Generated environment map as numpy array
        """
        # 1. Analyze Background
        img_arr = np.array(pil_img)
        mask_arr = np.array(pil_mask)
        if mask_arr.max() <= 1:
            mask_arr = (mask_arr * 255).astype(np.uint8)
        if len(mask_arr.shape) > 2:
            mask_arr = mask_arr[:, :, 0]
        
        bg_mask = cv2.bitwise_not(mask_arr)
        mean_color = cv2.mean(img_arr, mask=bg_mask)[:3]
        user_bg_rgb = [mean_color[0], mean_color[1], mean_color[2]]
        
        # 2. Find Match
        with open(self.metadata_path, 'r') as f:
            metadata_db = json.load(f)
        
        best_match = None
        min_dist = float('inf')
        for item in metadata_db:
            dist = np.sqrt(sum((c1 - c2)**2 for c1, c2 in zip(user_bg_rgb, item['ambient_rgb'])))
            if dist < min_dist:
                min_dist = dist
                best_match = item
        
        print(f"Match Found: {best_match['id']}")
        
        # 3. Load Base Map
        full_path = os.path.join(self.exr_folder, best_match['id'])
        env_map = cv2.imread(full_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)
        h, w, c = env_map.shape
        
        # 4. Render Lights
        if lights_json_path and os.path.exists(lights_json_path):
            with open(lights_json_path, 'r') as f:
                data = json.load(f)
            
            if "lights" in data:
                print(f"→ Rendering {len(data['lights'])} custom lights...")
                light_layer = self.render_multi_light_layer(w, h, data['lights'])
                final_map = env_map + light_layer
            else:
                print("→ Warning: JSON missing 'lights' key.")
                final_map = env_map
        else:
            print("→ Fallback: No JSON provided.")
            final_map = env_map
        
        # 5. Save if output path provided
        if output_path:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            cv2.imwrite(output_path, final_map)
            print(f"✅ Saved environment map to: {output_path}")
        
        return final_map
    
    def create_lights_json(
        self,
        lights_config: List[Dict],
        output_path: str = "./multi_lights.json"
    ) -> str:
        """
        Create a lights JSON file from a configuration.
        
        Args:
            lights_config: List of light configuration dictionaries
            output_path: Path to save the JSON file
            
        Returns:
            Path to the created JSON file
        """
        lights_data = {"lights": lights_config}
        
        os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(lights_data, f, indent=2)
        
        print(f"✅ Created lights JSON: {output_path}")
        return output_path


# Convenience functions for backward compatibility
def generate_targeted_env_map(
    pil_img: Image.Image,
    pil_mask: Image.Image,
    lights_json_path: Optional[str] = None,
    metadata_path: str = "./content/envmapsmetadata.json",
    exr_folder: str = "./content/",
    output_path: Optional[str] = None
) -> np.ndarray:
    """
    Convenience function to generate a targeted environment map.
    
    Args:
        pil_img: Input PIL image
        pil_mask: Segmentation mask as PIL image
        lights_json_path: Path to JSON file containing light specifications
        metadata_path: Path to environment map metadata JSON
        exr_folder: Folder containing .exr files
        output_path: Optional path to save the generated environment map
        
    Returns:
        Generated environment map as numpy array
    """
    generator = EnvMapGenerator(metadata_path, exr_folder)
    return generator.generate_targeted_env_map(pil_img, pil_mask, lights_json_path, output_path)
