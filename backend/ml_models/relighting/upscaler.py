"""
Upscaler module for Real-ESRGAN integration with relighting pipeline.
Provides a simple interface to upscale images using Real-ESRGAN models.
"""
import os
import torch
import numpy as np
from PIL import Image

# Use absolute imports instead of relative imports
from realesrgan import RealESRGANer, SRVGGNetCompact, RRDBNet


# Global upsampler instance (lazy loaded)
_upsampler = None


def get_upsampler(model_name='RealESRGAN_x4plus', scale=4, tile=0, tile_pad=10, pre_pad=0, half=True):
    """
    Get or initialize the Real-ESRGAN upsampler.
    
    Args:
        model_name (str): Model name. Options: 'RealESRGAN_x4plus', 'realesr-general-x4v3', 'realesr-animevideov3'
        scale (int): Upscaling factor (default: 4)
        tile (int): Tile size for processing large images (0 = no tiling)
        tile_pad (int): Padding for tiles
        pre_pad (int): Pre-padding
        half (bool): Use half precision (fp16) for faster inference
        
    Returns:
        RealESRGANer: Initialized upsampler instance
    """
    global _upsampler
    
    if _upsampler is not None:
        return _upsampler
    
    # Define model architecture and weights path based on model name
    if model_name == 'RealESRGAN_x4plus':
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        netscale = 4
        model_path = os.path.join(os.path.dirname(__file__), 'realesrgan', 'weights', 'RealESRGAN_x4plus.pth')
    elif model_name == 'realesr-general-x4v3':
        model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=32, upscale=4, act_type='prelu')
        netscale = 4
        model_path = os.path.join(os.path.dirname(__file__), 'realesrgan', 'weights', 'realesr-general-x4v3.pth')
    elif model_name == 'realesr-animevideov3':
        model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type='prelu')
        netscale = 4
        model_path = os.path.join(os.path.dirname(__file__), 'realesrgan', 'weights', 'realesr-animevideov3.pth')
    else:
        raise ValueError(f"Unknown model name: {model_name}")
    
    # Check if model weights exist
    if not os.path.isfile(model_path):
        print(f"❌ Model weights not found at {model_path}")
        print(f"Please download the model from:")
        if model_name == 'RealESRGAN_x4plus':
            print(f"https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth")
        else:
            print(f"https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/{os.path.basename(model_path)}")
        print(f"and place it in: {os.path.dirname(model_path)}")
        return None
    
    print(f"✓ Loading {model_name} from {model_path}")
    
    # Initialize upsampler
    try:
        _upsampler = RealESRGANer(
            scale=netscale,
            model_path=model_path,
            model=model,
            tile=tile,
            tile_pad=tile_pad,
            pre_pad=pre_pad,
            half=half and torch.cuda.is_available()
        )
        print(f"✓ RealESRGAN upsampler initialized successfully")
    except Exception as e:
        print(f"❌ Failed to initialize RealESRGAN: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    return _upsampler
