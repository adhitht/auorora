import numpy as np
from diffusers import DiffusionPipeline
import torch
import kornia
from PIL import Image
from ..utils.image_ops import preprocess_object
from config import cfg
from diffusers.utils.torch_utils import randn_tensor


class RelightPipeline(DiffusionPipeline):
    """
    - Concatenate along channels: [x_t (4), x_img (4), env_hdr (4), env_ldr (4)] -> 16.
    - Use CLIP image embedding as encoder_hidden_states.
    """

    def __init__(self, vae, unet, scheduler, feature_extractor, image_encoder):
        super().__init__()
        self.register_modules(
            vae=vae,
            unet=unet,
            scheduler=scheduler,
            feature_extractor=feature_extractor,
            image_encoder=image_encoder
        )
        self.vae_scale_factor = 2 ** (len(self.vae.config.block_out_channels) - 1)

    @property
    def device(self):
        return self.unet.device

    def CLIP_preprocess(self, x):
        """
        CLIP preprocessing using kornia
        """
        dtype = x.dtype

        # following openai's implementation
        if isinstance(x, torch.Tensor):
            if x.min() < -1.0 or x.max() > 1.0:
                raise ValueError("Expected input tensor to have values in the range [-1, 1]")
        x = kornia.geometry.resize(x. to(torch.float32), (224, 224),
                                   interpolation='bicubic', align_corners=True,
                                   antialias=False). to(dtype=dtype)
        x = (x + 1.) / 2.
        # renormalize according to clip
        x = kornia.enhance.normalize(x, torch. Tensor([0.48145466, 0.4578275, 0.40821073]),
                                     torch.Tensor([0.26862954, 0.26130258, 0.27577711]))
        return x

    @torch.no_grad()
    def __call__(
        self,
        image: Image.Image,
        mask: np.ndarray,
        first_target_envir_map: torch.Tensor,
        second_target_envir_map: torch.Tensor,
        num_inference_steps: int = 50,
        guidance_scale: float = 3.0,
        generator=None
    ):
        device = self.device
        dtype  = self.vae.dtype

#-------PREPROCESSING---------
        proc_img, meta = preprocess_object(image, mask, target_res=cfg.TARGET_RES, bg_value=cfg.BG_COLOR)
        img_np   = np.array(proc_img). astype(np.float32) / 255.0
        img_t    = torch.from_numpy(img_np).permute(2, 0, 1).unsqueeze(0)  # [1,3,H,W]
        img_t    = (img_t * 2.0 - 1.0).to(device, dtype=dtype)

        #encode input image to latents
        img_latent = self.vae.encode(img_t).latent_dist.mode()

#-------CLIP imgage EMBEDDING-----------

        #convert processed image to tensor format for CLIP preprocessing
        img_for_clip = img_t
        x_clip = self.CLIP_preprocess(img_for_clip)
        image_embeds = self.image_encoder(x_clip).image_embeds   #[1,768]
        image_embeds = image_embeds.unsqueeze(1)                # [1,1,768]

#-------HDRI processing--------
        #encoding the maps
        first_target_envir_map = first_target_envir_map.to(device, dtype=dtype)
        first_envir_latent = self.vae.encode(first_target_envir_map).latent_dist.mode()

        second_target_envir_map = second_target_envir_map.to(device, dtype=dtype)
        second_envir_latent = self.vae.encode(second_target_envir_map).latent_dist.mode()

#-------CFG--------
        do_cfg = guidance_scale > 1.0

        #preparing conditioning for CFG
        if do_cfg:
            #for unconditioned
            img_latent = torch.cat([torch.zeros_like(img_latent), img_latent], dim=0)
            first_envir_latent = torch.cat([torch.zeros_like(first_envir_latent), first_envir_latent], dim=0)
            second_envir_latent = torch.cat([torch.zeros_like(second_envir_latent), second_envir_latent], dim=0)

            #CLIP embeddings
            uncond_embeds = torch.zeros_like(image_embeds)
            cond_embeds   = torch.cat([uncond_embeds, image_embeds], dim=0)  # [2,1,768]
        else:
            cond_embeds = image_embeds

        self.scheduler.set_timesteps(num_inference_steps, device=device)
        timesteps = self.scheduler.timesteps

        #generating pure noise in latent space, 4 channels
        latent_shape = (1, 4, cfg.TARGET_RES // 8, cfg.TARGET_RES // 8)
        latents = randn_tensor(latent_shape, generator=generator, device=device, dtype=dtype)
        latents = latents * self.scheduler.init_noise_sigma

#-------Denoising loop with 16-channel concatenation----------
        num_warmup_steps = len(timesteps) - num_inference_steps * self.scheduler.order
        with self.progress_bar(total=num_inference_steps) as progress_bar:
            for i, t in enumerate(timesteps):
                #expanding latents
                latent_model_input = torch.cat([latents] * 2) if do_cfg else latents

                #scaling model inputs
                latent_model_input = self.scheduler.scale_model_input(latent_model_input, t)

                #channel concatenation
                #[latent_model_input (4), img_latents (4), first_envir (4), second_envir (4)] = 16 channels
                latent_model_input = torch.cat([
                    latent_model_input,
                    img_latent,
                    first_envir_latent,
                    second_envir_latent
                ], dim=1)

                #predict noise
                noise_pred = self.unet(
                    latent_model_input,
                    t,
                    encoder_hidden_states=cond_embeds,
                    return_dict=False
                )[0]

                #perform CFG
                if do_cfg:
                    noise_pred_uncond, noise_pred_text = noise_pred. chunk(2)
                    noise_pred = noise_pred_uncond + guidance_scale * (noise_pred_text - noise_pred_uncond)

                
                latents = self. scheduler.step(noise_pred, t, latents, return_dict=False)[0]

                if i == len(timesteps) - 1 or ((i + 1) > num_warmup_steps and (i + 1) % self. scheduler.order == 0):
                    progress_bar.update()

#-------Decoding step------------
        latents = 1 / self. vae.config.scaling_factor * latents
        image   = self.vae.decode(latents, return_dict=False)[0]
        image   = (image / 2 + 0.5).clamp(0, 1)
        image   = image.cpu().permute(0, 2, 3, 1).float().numpy()
        return self.numpy_to_pil(image)[0], meta
