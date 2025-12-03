#!/usr/bin/env python3
"""
CLI to run the relighting flow locally or in cloud containers.

Example:
  python run_relight.py --image vege_dog.jpg --mask mask.png --hdri 012_hdrmaps_com_free_2K.exr --rot 210
  
With custom environment map generation:
  python run_relight.py --image vege_dog.jpg --mask mask.png --generate-env-map --lights-json my_lights.json
"""
import argparse
import numpy as np
import json
from pathlib import Path
from PIL import Image
from src.runner.relight_runner import init_models, relight_object
from config import cfg


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--image", required=True, help="Path to input image")
    p.add_argument("--mask", required=True, help="Path to binary mask image")
    p.add_argument("--hdri", help="Path to HDRI file (optional if --generate-env-map is used)")
    p.add_argument("--rot", default=0.0, type=float, help="HDRI rotation angle")
    p.add_argument("--guidance", default=3.0, type=float, help="Guidance scale")
    p.add_argument("--seed", default=None, type=int, help="Random seed")
    p.add_argument("--use-shadows", action="store_true", help="Enable shadow composition")
    p.add_argument("--shadow-reach", default=0.4, type=float, help="Shadow distance (0.0-1.0)")
    p.add_argument("--debug", action="store_true", help="Show shadow debug plots")
    
    # Environment map generation options
    p.add_argument("--generate-env-map", action="store_true", help="Generate custom environment map from background analysis")
    p.add_argument("--lights-json", help="Path to JSON file with custom light configurations")
    
    # Upscaling options (enabled by default)
    p.add_argument("--upscale", default=2, type=int, choices=[1, 2, 4], help="Upscaling factor for relit object (default: 2x, options: 1/2/4)")
    p.add_argument("--no-realesrgan", action="store_true", help="Disable Real-ESRGAN upscaling (use LANCZOS instead)")
    
    args = p.parse_args()
    
    # Validate arguments
    if not args.generate_env_map and not args.hdri:
        p.error("Either --hdri or --generate-env-map must be specified")

    # Load mask
    mask_img = Image.open(args.mask).convert("L")
    mask = np.array(mask_img) > 127  # Binary threshold

    # Initialize models
    pipe = init_models()

    if pipe is None:
        print("Pipeline failed to initialize.")
        return
    
    # Load lights configuration if provided
    lights_config = None
    if args.lights_json:
        with open(args.lights_json, 'r') as f:
            data = json.load(f)
            # Support both {"lights": [...]} and direct [...] formats
            lights_config = data.get('lights', data) if isinstance(data, dict) and 'lights' in data else data
        print(f"💡 Loaded {len(lights_config)} light configurations")
    
    # Set default HDRI path
    hdri_path = args.hdri if args.hdri else None

    res, mask, meta = relight_object(
        pipe, args.image, mask, hdri_path,
        rot_angle=args.rot, 
        guidance_scale=args.guidance, 
        seed=args.seed,
        use_shadows=args.use_shadows, 
        shadow_reach=args.shadow_reach,
        debug=args.debug,
        lights_config=lights_config,
        generate_env_map=args.generate_env_map,
        upscale_factor=args.upscale,
        use_realesrgan=not args.no_realesrgan
    )

    out = Path("relit_output.png")
    print(f"Done. Output: {out.resolve()}")


if __name__ == "__main__":
    main()
