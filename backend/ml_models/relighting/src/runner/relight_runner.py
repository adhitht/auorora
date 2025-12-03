import time
import torch
import numpy as np
import os
from PIL import Image
from typing import Optional, Dict, List
from config import cfg
from src.models.neural_gaffer import build_pipeline
from src.utils.image_ops import read_hdri_map, composite_relit, generate_env_map_from_image
import upscaler


def relight_object(pipe, depth_estimator, upsampler, image_path, mask, hdri_path,
                  rot_angle=0.0, guidance_scale=3.0, seed=None, num_inference_steps=50,
                  shadow_reach=0.4, debug=False,
                  lights_config: Optional[List[Dict]] = None,
                  upscale_factor=2, use_realesrgan=True):
    """Wrapper to produce a relit image given a mask and a HDRI.

    Saves `relit_output.png` and returns (PIL.Image, mask, meta).
    
    Args:
        pipe: The relighting pipeline
        depth_estimator: Pre-loaded depth estimation model
        image_path : Image, can be path or Image.image instance
        mask: Binary mask for the object
        hdri_path: Path to HDRI environment map
        shadow_reach: Controls how far shadows extend (0.0-1.0)
        lights_config: Optional list of light configurations for custom env map generation
        upscale_factor: Upscaling factor (default: 2, for CLI use only)
        use_realesrgan: Use Real-ESRGAN (default: True, for CLI use only)
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
        
    #call final composition function
    final_result = composite_relit(
        depth_estimator=depth_estimator,
        upsampler=upsampler,
        original_pil=original_pil,
        relit_pil=result,
        mask=mask,
        meta=meta,
        hdri_path=hdri_path,
        rot_angle=rot_angle,
        shadow_reach=shadow_reach,
        debug=debug,
        upscale_factor=upscale_factor,
        use_realesrgan=use_realesrgan
    )
    
    final_result.save("relit_output.png")
    return final_result, mask, meta



def init_models():
    pipe = build_pipeline()
    upsampler_model = upscaler.init_upsampler()
    if upsampler_model is None:
        print("[WARNING] : Real-ESRGAN upsampler could not be loaded, will fallback to LANCZOS")
    return pipe, upsampler_model
