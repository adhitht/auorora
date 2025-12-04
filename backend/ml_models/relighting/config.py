import yaml
import torch
from pathlib import Path

class Config:
    def __init__(self, path=None):
        config_dir = Path(__file__).parent
        
        if path is None:
            path = config_dir / "config.yaml"
        
        with open(path, "r") as f:
            cfg = yaml.safe_load(f)

        #dynamic CUDA/dtype setup
        self.DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
        self.DTYPE = torch.float16 if "cuda" in self.DEVICE else torch.float32
        self.DEVICE_SAM2 = cfg.get("device_sam2", self.DEVICE)

        #object settings
        self.TARGET_RES = cfg["target_resolution"]
        self.BG_COLOR = cfg["background_color"]

        #neural gaffer
        self.BASE_MODEL_ID = cfg["neural_gaffer"]["base_model_id"]
        gaffer_ckpt = cfg["neural_gaffer"]["checkpoint_dir"]

        if not Path(gaffer_ckpt).is_absolute():
            self.GAFFER_CKPT_DIR = str(config_dir / gaffer_ckpt)
        else:
            self.GAFFER_CKPT_DIR = gaffer_ckpt

        #Env map generator
        env_map_cfg = cfg.get("env_map", {})
        
        env_metadata = env_map_cfg.get("metadata_path", "./env_map/envmapsmetadata.json")
        if not Path(env_metadata).is_absolute():
            self.ENV_MAP_METADATA_PATH = str(config_dir / env_metadata)
        else:
            self.ENV_MAP_METADATA_PATH = env_metadata
            
        env_folder = env_map_cfg.get("exr_folder", "./env_map/")
        if not Path(env_folder).is_absolute():
            self.ENV_MAP_EXR_FOLDER = str(config_dir / env_folder)
        else:
            self.ENV_MAP_EXR_FOLDER = env_folder
            
        self.ENV_MAP_LIGHT_THRESHOLD = env_map_cfg.get("light_source_threshold", 20.0)
        self.ENV_MAP_ENABLE_CUSTOM = env_map_cfg.get("enable_custom_generation", True)
        
        # Upsampler config
        upsampler_cfg = cfg.get("upsampler", {})
        self.UPSAMPLER_USE_TILING = upsampler_cfg.get("use_tiling", False)

    def __repr__(self):
        return f"<Config DEVICE={self.DEVICE}, DTYPE={self.DTYPE}, TARGET_RES={self.TARGET_RES}>"


cfg = Config()
