import os
import torch
from safetensors.torch import load_file
from diffusers import UNet2DConditionModel, AutoencoderKL, DDIMScheduler
from transformers import CLIPVisionModelWithProjection, CLIPImageProcessor
from config import cfg

from src.pipeline.relight_pipeline import RelightPipeline


def load_neural_gaffer_unet_weights(unet, checkpoint_folder: str):
	"""
	Load available Neural Gaffer UNet weights.
	"""

	checkpoint_path = os.path.join(checkpoint_folder, "model.safetensors")


	print(f"Loading NG UNet weights: {checkpoint_path}")

	state_dict = load_file(checkpoint_path)
	
	#remove prefixes
	cleaned = {}
	for k, v in state_dict.items():
		k2 = k
		if k2.startswith("module."):
			k2 = k2[7:]
		if k2.startswith("unet."):
			k2 = k2[5:]
		cleaned[k2] = v

	missing, unexpected = unet.load_state_dict(cleaned, strict=False)
	print(f"✓ Loaded UNet (missing={len(missing)}, unexpected={len(unexpected)})")
	return unet


def build_pipeline():
	"""
	Constructs a RelightPipeline from base model IDs and
	load Neural Gaffer UNet weights from `cfg.GAFFER_CKPT_DIR`.

	Returns a ready-to-use `RelightPipeline` on `cfg.DEVICE`.
	"""
	BASE_MODEL_ID = cfg.BASE_MODEL_ID
	DTYPE = cfg.DTYPE
	DEVICE = cfg.DEVICE
	GAFFER_CKPT_DIR = cfg.GAFFER_CKPT_DIR

	print(f"Loading base models from {BASE_MODEL_ID}...")
	vae = AutoencoderKL.from_pretrained(BASE_MODEL_ID, subfolder="vae", torch_dtype=DTYPE)
	unet = UNet2DConditionModel.from_pretrained(BASE_MODEL_ID, subfolder="unet", torch_dtype=DTYPE)
	sched = DDIMScheduler.from_pretrained(BASE_MODEL_ID, subfolder="scheduler")
	feat = CLIPImageProcessor.from_pretrained(BASE_MODEL_ID, subfolder="feature_extractor")
	clip = CLIPVisionModelWithProjection.from_pretrained(BASE_MODEL_ID, subfolder="image_encoder", torch_dtype=DTYPE)

    #modifying conv_in to accept 16 channels as in neural gaffer architecture
	old_conv = unet.conv_in
	new_conv = torch.nn.Conv2d(
        in_channels=16,
        out_channels=old_conv.out_channels,
        kernel_size=old_conv.kernel_size,
        stride=old_conv.stride,
        padding=old_conv.padding,
        dilation=old_conv.dilation,
        bias=old_conv.bias is not None,
        dtype=DTYPE,  # Ensure dtype matches
        device=old_conv.weight.device
    )

    #initialze new conv_in and copy the first 8 channels from previous one
	with torch.no_grad():
		torch.nn.init.zeros_(new_conv.weight)
		new_conv.weight[:, :8, :, :].copy_(old_conv.weight)
		if old_conv.bias is not None:
			new_conv.bias.copy_(old_conv.bias)
	
	unet.conv_in = new_conv
	unet.config.in_channels = 16

	#load the weights
	unet = load_neural_gaffer_unet_weights(unet, GAFFER_CKPT_DIR)

	pipe = RelightPipeline(vae, unet, sched, feat, clip).to(DEVICE)
	return pipe

