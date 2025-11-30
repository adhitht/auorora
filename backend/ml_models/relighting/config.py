import yaml
import torch

class Config:
    def __init__(self, path="config.yaml"):
        with open(path, "r") as f:
            cfg = yaml.safe_load(f)

        # dynamic CUDA/dtype setup
        self.DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
        self.DTYPE = torch.float16 if "cuda" in self.DEVICE else torch.float32
        self.DEVICE_SAM2 = cfg.get("device_sam2", self.DEVICE)

        # object settings
        self.TARGET_RES = cfg["target_resolution"]
        self.BG_COLOR = cfg["background_color"]

        # SAM2
        self.SAM2_CHECKPOINT = cfg["sam2"]["checkpoint"]
        self.SAM2_CONFIG = cfg["sam2"]["config"]

        # Neural Gaffer
        self.BASE_MODEL_ID = cfg["neural_gaffer"]["base_model_id"]
        self.GAFFER_CKPT_DIR = cfg["neural_gaffer"]["checkpoint_dir"]

        # Environment Map Generator
        env_map_cfg = cfg.get("env_map", {})
        self.ENV_MAP_METADATA_PATH = env_map_cfg.get("metadata_path", "./content/envmapsmetadata.json")
        self.ENV_MAP_EXR_FOLDER = env_map_cfg.get("exr_folder", "./content/")
        self.ENV_MAP_LIGHT_THRESHOLD = env_map_cfg.get("light_source_threshold", 20.0)
        self.ENV_MAP_ENABLE_CUSTOM = env_map_cfg.get("enable_custom_generation", True)

    def __repr__(self):
        return f"<Config DEVICE={self.DEVICE}, DTYPE={self.DTYPE}, TARGET_RES={self.TARGET_RES}>"

# Create a singleton-style instance
cfg = Config()
