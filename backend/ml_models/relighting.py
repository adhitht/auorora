import sys
from pathlib import Path
import numpy as np
from PIL import Image
from typing import Optional, List, Dict

relighting_path = Path(__file__).parent / "relighting"
sys.path.insert(0, str(relighting_path))

from src.runner.relight_runner import init_models, relight_object


class RelightingModel:
    def __init__(self):
        """Initialize the relighting pipeline."""
        print("Initializing Relighting Model...")
        self.pipeline = init_models()
        if self.pipeline is None:
            raise RuntimeError("Failed to initialize relighting pipeline")
        print("Relighting Model initialized successfully")

    def predict(self, image, mask, hdri_path=None, lights_config=None, 
                rot_angle=0.0, guidance_scale=3.0, seed=None, 
                num_inference_steps=50, shadow_reach=0.4, debug=False):
        """
        Perform relighting on an object in an image.
        
        Args:
            image: PIL Image object or path to image file
            mask: Binary mask array (numpy) or PIL Image indicating the object region
            hdri_path: Path to HDRI environment map (optional if lights_config is provided)
            lights_config: Optional list of light configurations for custom env map generation
            rot_angle: HDRI rotation angle in degrees (default: 0.0)
            guidance_scale: Diffusion guidance scale (default: 3.0)
            seed: Random seed for reproducibility (optional)
            num_inference_steps: Number of diffusion steps (default: 50)
            shadow_reach: Controls shadow distance 0.0-1.0 (default: 0.4)
            debug: Enable debug output (default: False)
            
        Returns:
            tuple: (relit_image: PIL Image, mask: numpy array, metadata: dict)
        """
        # Convert mask to numpy array if it's a PIL Image
        if isinstance(mask, Image.Image):
            mask = np.array(mask.convert("L")) > 127
        
        #call the function
        relit_image, mask, meta = relight_object(
            pipe=self.pipeline,
            image_path=image,
            mask=mask,
            hdri_path=hdri_path,
            rot_angle=rot_angle,
            guidance_scale=guidance_scale,
            seed=seed,
            num_inference_steps=num_inference_steps,
            shadow_reach=shadow_reach,
            debug=debug,
            lights_config=lights_config
        )
        
        return relit_image, mask, meta
