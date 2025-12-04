<div align="center">
  <img src="assets/header.png" alt="Aurora Header" width="55%" />

  **Editing app for the future**

  [![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)](https://flutter.dev)
  [![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://www.python.org)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
</div>

A comprehensive image editing and manipulation application featuring AI-powered tools for pose correction, relighting, inpainting. The project combines a Flutter frontend with a Python gRPC backend for advanced image processing capabilities.

## Description

Aurora Image Editing Suite is a full-stack application designed to provide professional image editing capabilities with AI-powered models. The application features:

- **Pose Correction & Reframe**: Adjust and modify human poses and object position in images using masks and pose landmarks
- **Relighting**: Dynamically relight images with customizable light configurations
- **Smart Editing Tools**: Context-aware inpainting and background manipulation

The application features a high-performance **Flutter** frontend optimized for modern Android devices. Its robust **Python** backend utilizes **gRPC** for efficient, low-latency communication, orchestrating state-of-the-art machine learning models for advanced image processing.

## File Structure

```
aurora/
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

### 🛠️ Tech Stack

#### Backend (Python 3.9+)
- **Communication**: gRPC with Protocol Buffers
- **Core**: `grpcio`, `protobuf`, `pydantic`, `numpy`, `Pillow`, `opencv-python-headless`
- **ML Frameworks**: `torch`, `torchvision`, `transformers`, `diffusers`, `peft`
- **Specialized Models**: `mediapipe` (Pose), `ultralytics` (YOLO), `timm`

#### Frontend (Flutter 3.9.2+)
- **Framework**: Flutter 3.9.2+
- **Image Processing**: `image_picker`, `image`, `crop_image`
- **ML on Device**: `tflite_flutter`, `onnxruntime_v2`
- **Communication**: `grpc`, `flutter_dotenv`
- **UI/UX**: `google_fonts`, `flutter_svg`, `liquid_glass_renderer`, `share_plus`, `path_provider`, `cupertino_icons`

## Local Testing

### Prerequisites
- **Backend**: Python 3.9 or higher, pip
- **Frontend**: Flutter 3.9.2+, Dart
- **Platform-specific**: 
  - iOS: Xcode 14+
  - Android: Android Studio, SDK 21+
  - Windows: Visual Studio Build Tools
  - macOS: Xcode Command Line Tools
  - Linux: Build essentials

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   # On Windows
   venv\Scripts\activate
   # On macOS/Linux
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Regenerate protobuf files (if proto files were modified):
   ```bash
   python -m grpc_tools.protoc -I../protos --python_out=. --grpc_python_out=. ../protos/pose.proto
   python -m grpc_tools.protoc -I../protos --python_out=. --grpc_python_out=. ../protos/relighting.proto
   ```

5. Start the gRPC server:
   ```bash
   python -m backend.main
   ```
   The server will start on `localhost:50051`

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Generate protobuf Dart files:
   ```bash
   dart run grpc:protoc_plugin
   protoc --dart_out=grpc:lib/generated -I../protos ../protos/pose.proto
   protoc --dart_out=grpc:lib/generated -I../protos ../protos/relighting.proto
   ```

4. Run on your target platform:
   ```bash
   flutter run
   flutter run -d <device_id>
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux
   ```

### Testing Communication

Ensure both backend and frontend are running on the same network. Configure the backend URL in the frontend:

- Update the gRPC channel in `frontend/lib/services/` to point to your backend server
- Default: `localhost:50051` for local testing

## User Workflow

<!-- TODO: Add GIFS here later -->

### 📱 Mobile/Desktop Application Flow

**1. Launch Application**
   - Open the Aurora image editing application
   - Application loads available editing tools

**2. Image Selection**
   - Select an image from gallery or camera
   - Image is displayed in the editor canvas

**3. Select Editing Tool**
   - Choose from available tools:
     - 🧘 **Pose Correction and Reframe**
     - 💡 **Relighting**
     - 🎯 **Context-aware Auto Suggestion**

**4. Configure Tool Parameters**

   <details>
   <summary><b>Pose & Reframe Tool</b></summary>
   
   - Choose the object/subject to be edited
   - Adjust pose landmarks by dragging points
   - Select region and drag to move
   - Preview changes in real-time
   - Confirm and apply changes
   </details>

   <details>
   <summary><b>Relighting Tool</b></summary>

   - Choose the object to be relit
   - Select light positions and intensity
   - Adjust color temperature
   - Preview relit image
   - Apply changes
   </details>

**5. Processing**
   - Frontend sends request to backend via gRPC
   - Backend processes image using appropriate ML model
   - Processed image returned to frontend
   - Result displayed with before/after comparison

**6. Edit History**
   - Maintain edit history for undo/redo
   - User can revert to previous versions

**7. Export**
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

### Pose Correction and Reframe Pipeline

The pose correction pipeline enables users to adjust and modify human poses in images through landmark manipulation.

**Pipeline Components** (`backend/ml_models/pose_change.py`):
1. **Pose Detection**: MediaPipe extracts 33 body landmarks from the input image
2. **Landmark Transform**: User-provided offset configurations adjust landmark positions
3. **Pose Warping**: Applied transformation to remap pixels based on modified pose
4. **Blending**: Seamless integration of transformed regions with original image context

The object reframing pipeline intelligently detects, extracts, relocates, and reintegrates objects within an image while maintaining visual harmony.

**Pipeline Components**:
1. **Object Detection & Segmentation**: Utilizes MagicTouch to detect objects in user-selected regions.
2. **Object Extraction**: Extracts the foreground object patch from the original image based on depth.
3. **Background Restoration**: The original region where the object was removed is inpainted using LaMa (dilated convolution) for structural restoration
4. **Object Placement**: Seamless integration of transformed regions with original image context

**Input Parameters**:
- Original image (RGB format)
- Offset configuration (JSON with landmark adjustments)
- Object selection coordinates
- Transform parameters for translation
- Optional mask for region-specific processing
   
**Output**:
- Pose-corrected, reframed image maintaining visual coherence

**Performance Considerations**:
- Real-time landmark detection (< 50ms on CPU)
- Warping complexity scales with image resolution
- Recommended resolution: 512×768 for optimal quality/speed trade-off
- Typical runtime: 1–5 seconds
- Memory: 1.5–3 GB VRAM

### Relighting Pipeline

The relighting pipeline dynamically adjusts lighting conditions in images with customizable light configurations.

**Pipeline Components** (`backend/ml_models/relighting.py`):
1. **Semantic Understanding**: Analyzes image composition
2. **Light Configuration**: Accepts user-defined light positions, intensity, and color
3. **Environment Map Generation**: Creates environment maps based on config
4. **Neural Relighting**: MiGAN model applies learned relighting transformations

**Input Parameters**:
- Original image
- Light configuration (JSON with light properties):
  - Light positions
  - Intensity values
  - Color temperature
- Mask for object

**Output**:
- Relit image with adjusted lighting conditions

**Performance Considerations**:
- Model inference: under 10 seconds for 1024x1024 images
- GPU acceleration recommended for production use
- Memory requirement: ~GB VRAM for batch processing

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
- 

## 🛡️ Ethics & Transparency
#### Responsible AI Editing for 2030

Aurora is designed as a future-ready, ethical AI editor. Our goal is to provide powerful creative tools while ensuring user consent, transparency, and responsible model usage.

### AI Edit Disclosure
An AI-Edit Disclosure Panel communicates which parts of the image were changed and which models powered the edit.    
- **In-App Provenance Badge**: A small badge is shown on exported images    
- **C2PA-style Disclosure Panel**: Makes AI involvement clear, showing features applied, models used, sources    
- **Invisible provenance watermark**: Encoded in image using LSB embedding.    

### Edit Traceability & Modified-Region Detection
Aurora supports region-level transparency by computing an Edit Heat Map showing exactly which parts of the image were altered and including this in the metadata.

### Consent & Privacy Controls

Aurora includes an explicit, user-facing consent step before allowing any cloud-based AI processing.   
- **Cloud Processing Consent Prompt in UI**: We disclose that we mayhave to process user images on cloud, but these are not stored or used in training   
- **On-Device by Default**: Whenever possible, the app uses offline editing   

### Misuse Prevention & Ethical Guardrails

To prevent harmful or deceptive editing:

✔ No face-reshaping, identity manipulation, or deepfake creation   
✔ Pose correction limited to mild geometric adjustments    
✔ Sensitive images (IDs, minors, official documents) trigger warnings    

These constraints ensure ethical safety while retaining creative freedom.

### Open-Source Model Licensing Transparency

Every model used in the pipeline is open-source, auditable, and ethically licensed.
We avoid proprietary, opaque, or illegally sourced datasets.

Model Licensing Summary

- LaMa (Dilated) — MIT License. Fully open and unrestricted with attribution.

- MagicTouch.tflite — Derived from Google/Meta segmentation research (Apache 2.0).

- MobileSAM — Apache 2.0. Fully reproducible segmentation.

- MediaPipe Holistic — Apache 2.0, includes explicit anti-misuse guidelines.

- Stable Diffusion 1.5 — OpenRAIL-M license restricting harmful/deceptive use.
