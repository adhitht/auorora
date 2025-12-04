import os
import torch
import numpy as np
from PIL import Image
from config import cfg as config
from realesrgan import RealESRGANer, RRDBNet

_upsampler = None


def init_upsampler():
    """
    Initialize the Real-ESRGAN upsampler.
    Tiling can be enabled via config.yaml for low VRAM systems.

    Returns:
        RealESRGANer: Initialized upsampler instance
    """
    
    global _upsampler
    
    if _upsampler is not None:
        return _upsampler
    
    #load the model (RealESRGAN-x2plus)
    model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=2)
    netscale = 2
    
    #tiling config
    tile = 256 if config.UPSAMPLER_USE_TILING else 0
    model_path = os.path.join(os.path.dirname(__file__), 'realesrgan', 'weights', 'RealESRGAN_x2plus.pth')
    
    if not os.path.isfile(model_path):
        print(f"Model weights were not found at {model_path}")
        print(f"Please follow the setup instructions in README.MD to download the model weights.")
        return None
    
    
    #initialize upsampler
    try:
        _upsampler = RealESRGANer(
            scale=netscale,
            model_path=model_path,
            model=model,
            tile=tile,
            tile_pad=10,
            pre_pad=0,
            half=torch.cuda.is_available(),
            device=config.DEVICE
        )
    except Exception as e:
        print(f"Failed to initialize RealESRGAN: {e}")
        return None
    
    return _upsampler
