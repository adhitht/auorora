import time
import torch
import numpy as np
import os
from PIL import Image
from typing import Optional, Dict, List
from config import cfg
from src.models.neural_gaffer import build_pipeline
from src.utils.image_ops import read_hdri_map, composite_with_shadows, generate_env_map_from_image
from transformers import pipeline as hf_pipeline


def relight_object(pipe, image_path, mask, hdri_path,
                  rot_angle=0.0, guidance_scale=3.0, seed=None, num_inference_steps=50,
                  shadow_reach=0.4, debug=False,
                  lights_config: Optional[List[Dict]] = None):
    """Wrapper to produce a relit image given a mask and a HDRI.

    Saves `relit_output.png` and returns (PIL.Image, mask, meta).
    
    Args:
        image_path : Image, can be path or Image.image instance
        use_shadows: If True, composite shadows onto the original image
        shadow_reach: Controls how far shadows extend (0.0-1.0)
        lights_config: Optional list of light configurations for custom env map generation
    """
    #loading image
    if isinstance(image_path, str):
        original_pil = Image.open(image_path).convert("RGB")
    else:
        original_pil = image_path.convert("RGB")

    #generating custom environment map
    hdri_path = generate_env_map_from_image(
        pil_img=original_pil,
        pil_mask=Image.fromarray((mask * 255).astype(np.uint8)),
        lights_config=lights_config,
        output_path="./generated_env_map.exr"
    )

    #read HDRI map
    first_target_envir_map, second_target_envir_map = read_hdri_map(
        hdri_path, target_res=(cfg.TARGET_RES, cfg.TARGET_RES), rot_angle=rot_angle
    )

    generator = torch.Generator(device=cfg.DEVICE)
    
    if seed is not None:
        generator = torch.Generator(device=cfg.DEVICE).manual_seed(seed)

    start = time.time()
    result, meta = pipe(
        image=original_pil,
        mask=mask,
        first_target_envir_map=first_target_envir_map,
        second_target_envir_map=second_target_envir_map,
        num_inference_steps=num_inference_steps,
        guidance_scale=guidance_scale,
        generator=generator,
    )
    end = time.time()
    if debug:
        print("Diffusion took : ", end - start)

    #add shadows
        print("\n" + "=" * 60)
        print("Compositing with Shadows")
        print("=" * 60)
        
    # Initialize depth estimator
    depth_estimator = hf_pipeline("depth-estimation", model="depth-anything/Depth-Anything-V2-large-hf")
    
    final_result = composite_with_shadows(
        depth_estimator=depth_estimator,
        original_pil=original_pil,
        relit_pil=result,
        mask=mask,
        meta=meta,
        hdri_path=hdri_path,
        rot_angle=rot_angle,
        shadow_reach=shadow_reach,
        debug=debug
    )
    
    final_result.save("relit_output.png")
    return final_result, mask, meta



def init_models():

    return build_pipeline()
