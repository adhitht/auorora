# Aurora - Editing app for the future

A comprehensive image editing and manipulation application featuring AI-powered tools for pose correction, relighting, inpainting. The project combines a Flutter frontend with a Python gRPC backend for advanced image processing capabilities.

## Description

Aurora Image Editing Suite is a full-stack application designed to provide image editing capabilities AI models. The application features:

- **Pose Correction**: Adjust and modify human poses in images using pose landmarks
- **Relighting**: Dynamically relight images with customizable light configurations
- **Inpainting**: Remove unwanted objects and intelligently fill regions
- **Object Detection & Segmentation**: Identify and segment objects in images

The frontend is built with Flutter, we have tested this with android phones (works better with Snapdragon chips). The backend uses Python with gRPC for efficient communication and leverages state-of-the-art ML models for image processing.

## File Structure

```
adobe/
├── README.md                 # Project documentation
├── grpc.init.sh             # gRPC initialization script
├── protos/                  # Protocol Buffer definitions
│   ├── pose.proto          # Pose service definitions
│   └── relighting.proto    # Relighting service definitions
├── backend/                # Python backend server
│   ├── main.py            # Entry point for gRPC server
│   ├── service.py         # gRPC service implementations
│   ├── requirements.txt    # Python dependencies
│   ├── pose_pb2.py        # Generated pose protobuf
│   ├── pose_pb2_grpc.py   # Generated pose gRPC
│   ├── relighting_pb2.py  # Generated relighting protobuf
│   ├── relighting_pb2_grpc.py  # Generated relighting gRPC
│   ├── ml_models/         # ML model implementations
│   │   ├── pose_change.py # Pose correction pipeline
│   │   ├── relighting.py  # Relighting pipeline
│   │   └── relighting/    # Relighting model resources
│   │       ├── config.yaml
│   │       ├── create_env_map_metadata.py
│   │       ├── env_map_generator.py
│   │       ├── run_relight.py
│   │       └── env_map/
│   └── model/             # Data models
│       └── lights_model.py # Light configuration models
├── frontend/              # Flutter mobile/desktop application
│   ├── pubspec.yaml      # Flutter dependencies
│   ├── lib/              # Flutter source code
│   │   ├── main.dart     # Application entry point
│   │   ├── models/       # Data models (edit history, pose landmarks)
│   │   ├── screens/      # UI screens
│   │   ├── services/     # API and service layer
│   │   ├── theme/        # Theming and styles
│   │   ├── widgets/      # Reusable UI components
│   │   └── generated/    # Generated protobuf Dart files
│   ├── assets/           # Application assets
│   │   ├── models/       # ML model files (TFLITE, ONNX)
│   │   ├── demo/         # Demo images
│   │   ├── icons/        # App icons
│   │   └── suggestions.json
│   ├── android/          # Android-specific configuration
│   ├── ios/              # iOS-specific configuration
│   ├── windows/          # Windows-specific configuration
│   ├── macos/            # macOS-specific configuration
│   ├── linux/            # Linux-specific configuration
│   └── test/             # Flutter tests
```

## Tech Stack

### Backend
- **Runtime**: Python 3.9+
- **Communication**: gRPC with Protocol Buffers
- **Core Libraries**:
  - `grpcio` & `grpcio-tools`: gRPC framework
  - `protobuf`: Message serialization
  - `pydantic`: Data validation
  - `numpy`: Numerical operations
  - `Pillow`: Image processing
  - `opencv-python-headless`: Computer vision
  
### ML Models & Processing
- **Deep Learning Frameworks**:
  - `torch` & `torchvision`: PyTorch deep learning
  - `transformers`: Hugging Face transformer models
  - `diffusers`: Diffusion model pipelines
  - `peft`: Parameter-efficient fine-tuning
  
- **Specialized Models**:
  - `mediapipe`: Pose landmark detection
  - `ultralytics`: YOLO object detection
  - `timm`: PyTorch image models
  - `scipy`: Scientific computing
  - `accelerate`: Distributed training utilities

### Frontend
- **Framework**: Flutter 3.9.2+
- **Image Processing**:
  - `image_picker`: Image selection
  - `image`: Image manipulation
  - `crop_image`: Image cropping
  
- **ML on Device**:
  - `tflite_flutter`: TensorFlow Lite models
  - `onnxruntime_v2`: ONNX model inference
  
- **Communication**:
  - `grpc`: gRPC client for Dart
  - `flutter_dotenv`: Environment configuration
  
- **UI/UX**:
  - `google_fonts`: Custom typography
  - `flutter_svg`: SVG rendering
  - `liquid_glass_renderer`: Glass morphism effects
  - `share_plus`: Share functionality
  - `path_provider`: File system access
  - `cupertino_icons`: iOS-style icons

## User Workflow

<!-- TODO: Add GIFS here later -->


### Mobile/Desktop Application Flow

1. **Launch Application**
   - User opens the Apex image editing application
   - Application loads available editing tools

2. **Image Selection**
   - Select an image from gallery or camera
   - Image is displayed in the editor canvas

3. **Select Editing Tool**
   - Choose from available tools:
     - **Pose Correction**: Adjust human poses
     - **Relighting**: Modify lighting conditions
     - **Inpainting**: Remove/fill regions
     - **Background Edit**: Modify background

4. **Configure Tool Parameters**
   - **For Pose Tool**: 
     - Adjust pose landmarks by dragging points
     - Preview changes in real-time
     - Confirm and apply changes
   
   - **For Relighting Tool**:
     - Select light positions and intensity
     - Adjust color temperature
     - Preview relit image
     - Apply changes
   
   - **For Inpainting Tool**:
     - Paint/mark regions to remove
     - Select fill style (inpaint, remove object)
     - Preview result
     - Apply changes

5. **Processing**
   - Frontend sends request to backend via gRPC
   - Backend processes image using appropriate ML model
   - Processed image returned to frontend
   - Result displayed with before/after comparison

6. **Edit History**
   - Maintain edit history for undo/redo
   - User can revert to previous versions
   - Export final edited image

7. **Export**
   - Save edited image to device storage
   - Share to social media or messaging apps
   - Save as project for later editing

### Backend Processing Pipeline

1. **Request Reception** (gRPC Service)
   - Service receives image data and parameters
   - Validates input data

2. **Image Preprocessing**
   - Decode image from bytes
   - Load optional mask data
   - Prepare data for ML models

3. **Model Processing**
   - Run appropriate ML pipeline
   - Apply transformations based on parameters
   - Generate processed image

4. **Postprocessing**
   - Encode result to PNG/JPEG
   - Prepare response message
   - Send back to frontend

5. **Error Handling**
   - Graceful error handling with user-friendly messages
   - Logging for debugging

![Backend Processing Pipeline](assets/backend-processing-diagram.png)

## Models Used

### On-Device Models (Frontend)
- **DeepLabv3**: Semantic segmentation (`deeplabv3.tflite`)
- **Mobile SAM**: Prompt-based segmentation
  - Image encoder: `mobile_sam_image_encoder.tflite`
  - Mask decoder: `mobile_sam_mask_decoder.tflite`
- **Pose Landmark**: Human pose detection (`pose_landmark_full.tflite`)
- **Magic Touch**: Interactive segmentation (`magic_touch.tflite`)
- **Object Detection**: SamSAM object detection (`sam2_object_detection.tflite`)

### Server-Side Models (Backend)
- **LAMA**: Inpainting model (`lama_dilated/`)
- **MiGAN**: Relighting model (`migan_pipeline_v2.onnx`)
- **RainNet**: Image enhancement (`rainnet_512_int8.onnx`)
- **Pose Correction**: Human pose manipulation (custom pipeline)
- **MediaPipe**: Pose landmark detection
- **YOLOv8**: Object detection

### Supporting Models
- **SigLIP Tags**: Image tagging and classification
- **Transformers**: Various pretrained models for feature extraction


<!-- This is the start of Pipelines Architecture -->

## Pipelines Architecture

### Pose Correction Pipeline

The pose correction pipeline enables users to adjust and modify human poses in images through landmark manipulation.

**Pipeline Components** (`backend/ml_models/pose_change.py`):
1. **Pose Detection**: MediaPipe extracts 33 body landmarks from the input image
2. **Landmark Transform**: User-provided offset configurations adjust landmark positions
3. **Pose Warping**: Applied transformation to remap pixels based on modified pose
4. **Blending**: Seamless integration of transformed regions with original image context

**Input Parameters**:
- Original image (RGB format)
- Offset configuration (JSON with landmark adjustments)
- Optional mask for region-specific processing

**Output**:
- Pose-corrected image maintaining visual coherence

**Performance Considerations**:
- Real-time landmark detection (< 50ms on CPU)
- Warping complexity scales with image resolution
- Recommended resolution: 512×768 for optimal quality/speed trade-off

### Relighting Pipeline

The relighting pipeline dynamically adjusts lighting conditions in images with customizable light configurations.

**Pipeline Components** (`backend/ml_models/relighting.py`):
1. **Semantic Understanding**: Analyzes image composition and material properties
2. **Light Configuration**: Accepts user-defined light positions, intensity, and color
3. **Environment Map Generation**: Creates synthetic environment maps based on config
4. **Neural Relighting**: MiGAN model applies learned relighting transformations
5. **Post-processing**: Tone mapping and color correction for natural appearance

**Input Parameters**:
- Original image
- Light configuration (JSON with light properties):
  - Light positions (3D coordinates)
  - Intensity values
  - Color temperature
  - Shadow parameters
- Optional mask for region-specific relighting

**Output**:
- Relit image with adjusted lighting conditions

**Performance Considerations**:
- Model inference: 1-3 seconds for 512×512 images
- GPU acceleration recommended for production use
- Memory requirement: ~4GB VRAM for batch processing

### Inpainting Pipeline

Context-aware image inpainting to remove unwanted objects and intelligently fill regions.

**Pipeline Components**:
1. **Mask Processing**: Accepts user-painted or segmentation-based masks
2. **Feature Extraction**: Extracts surrounding context from non-masked regions
3. **LAMA Model**: Diffusion-based inpainting with large receptive field
4. **Refinement**: Post-processing to blend inpainted regions seamlessly

**Input Parameters**:
- Original image
- Binary mask indicating regions to inpaint
- Optional style hints or reference patterns

**Output**:
- Inpainted image with contextually appropriate content

**Performance Considerations**:
- Inference time: 2-4 seconds for 512×512 images
- Larger masks increase computational complexity
- Quality improves with clear surrounding context

<!-- This is the start of Compute Profile -->

## Compute Profile and Resource Requirements

### Development Environment

| Component | Minimum | Recommended | Optimal |
|-----------|---------|------------|---------|
| **CPU** | Quad-core (2.0 GHz) | 6-core (2.5 GHz) | 8+ core (3.0+ GHz) |
| **RAM** | 8 GB | 16 GB | 32 GB |
| **GPU** | None (CPU inference) | NVIDIA GTX 1660+ / Apple Silicon | NVIDIA A100 / RTX 4090 |
| **Storage** | 50 GB | 100 GB | 200+ GB |

### Production Deployment

#### Server Configuration
- **CPU Cores**: 8-16 cores (for thread pool processing)
- **RAM**: 32-64 GB (model loading + concurrent requests)
- **GPU**: NVIDIA A100/H100 or equivalent for high throughput
- **Network**: 1Gbps+ for streaming image data

#### Per-Request Resource Utilization
| Operation | CPU Time | GPU Time | Memory |
|-----------|----------|----------|--------|
| Pose Correction | 50-100ms | - | 200-400 MB |
| Relighting | 100-200ms | 1-2s | 1.5-2 GB |
| Inpainting | 100-200ms | 2-4s | 2-3 GB |

### Frontend Resource Profile

#### Mobile (iOS/Android)
- **Minimum RAM**: 4 GB
- **Storage**: 500 MB - 1 GB (with bundled models)
- **On-device Models**: ~300 MB total
- **Peak Memory**: 500-800 MB during inference

#### Desktop (Windows/macOS/Linux)
- **Minimum RAM**: 8 GB
- **Storage**: 2-3 GB (with all models)
- **GPU Support**: Optional (CUDA/Metal/Vulkan acceleration)
- **Peak Memory**: 2-4 GB during batch processing

## Runtime Decisions and Optimizations

### Model Execution Strategy

#### On-Device vs Cloud Processing

**On-Device Models** (Frontend - Real-time):
- DeepLabv3, Mobile SAM, Pose Landmark (TFLITE format)
- **Advantages**: Low latency (50-200ms), privacy, offline capability
- **Trade-offs**: Limited model complexity, device power consumption
- **Use Cases**: Quick previews, real-time segmentation, interactive tools

**Server-Side Models** (Backend - High-quality):
- LAMA (inpainting), MiGAN (relighting), YOLOv8 (detection)
- **Advantages**: High-quality results, complex operations, scalability
- **Trade-offs**: Network latency, server load, scalability challenges
- **Use Cases**: Final high-quality processing, intensive computations

### Optimization Techniques

#### 1. Model Quantization
- **INT8 Quantization**: 75% reduction in model size with minimal quality loss
- **Implemented Models**:
  - `rainnet_512_int8.onnx`: 4x faster inference than FP32
  - Mobile TFLITE models: 8-bit integer quantization

#### 2. Pipeline Parallelization
```
Frontend Request
    ↓
[Parallel on Backend]
├── Load Model
├── Preprocess Image
├── Execute Inference
└── Postprocess Results
    ↓
Return to Frontend
```

#### 3. Caching Strategy
- **Model Caching**: Models loaded once at server startup (5-10s overhead)
- **Request Caching**: Recent requests cached for identical parameters
- **TTL**: 5 minutes for cache entries to manage memory

#### 4. Adaptive Resolution
| User Device | Recommended Input Resolution | Output Resolution |
|-----------|------------------------------|------------------|
| Mobile (3GB RAM) | 256×384 | 512×768 |
| Mobile (6GB+ RAM) | 512×768 | 1024×1536 |
| Desktop | 1024×1536 | 2048×3072 |
| GPU-enabled | 2048×3072 | 4096×6144 |

### Memory Management

#### Backend Memory Strategy
```python
# Model Loading (One-time at startup)
relight_model = RelightingModel()  # ~2 GB
pose_model = PoseCorrectionPipeline()  # ~1 GB

# Per-Request Management
# Input image: 50-200 MB (depends on resolution)
# Working memory: 500 MB - 2 GB (varies by operation)
# Output buffer: Reused across requests
```

#### Memory Limits
- **Per-request timeout**: 5 minutes
- **Memory limit per operation**: 4 GB
- **Garbage collection**: Triggered after each request

### Latency Optimization

#### Expected Response Times (Local Network)

| Operation | On-Device (ms) | Server (ms) | Total (ms) |
|-----------|----------------|------------|-----------|
| Pose Detection | 150-200 | - | 150-200 |
| Relighting | - | 1000-3000 | 1050-3100 |
| Inpainting | - | 2000-5000 | 2050-5100 |

**Network Latency**: ~10-50ms (LAN), 50-200ms (WAN)

### Power Consumption Profiles

#### Frontend (Mobile)
- **Idle**: 50-100 mW
- **On-device inference**: 500-1500 mW
- **Screen + processing**: 3-5 W
- **Typical session**: 5-10% battery per hour active use

#### Backend Server
- **Idle**: 100-200 W
- **Single request processing**: 300-600 W
- **Peak load (4+ concurrent)**: 800-1200 W