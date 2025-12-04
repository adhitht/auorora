# Setup Guide

## Local Testing

### Prerequisites
- **Backend**: Python 3.12 (Tested), pip
- **Frontend**: Flutter 3.35.7 (Tested)
- **System**: Protocol Buffer Compiler (protoc)

### Backend Setup

1. Create a virtual environment (recommended):
   ```bash
   python -m venv venv

   # Activate the created virtual environment 
   # On Windows
   venv\Scripts\activate
   # On macOS/Linux
   source venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   pip install -r backend/requirements.txt
   ```

3. (Optional) If you want to add extra environment maps for relighting, then:
   - Add them to the `backend/ml_models/relighting/env_maps/`, following the format `envmap{i}.exr`, where `i` is the env map number
   - Run the `create_env_map_metadata.py` file to process the environment maps
   ```bash
   cd backend/ml_models/relighting/
   python create_env_map_metadata.py
   cd ../../..
   ```


4. Generate Proto files, download and place the model checkpoints in the intended directories.
   ```bash
   ./init.sh
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

3. Configure environment variables: Copy the example environment file to create your local configuration:
   ```bash
   cp env.example .env
   ```
   Open the `.env` file and ensure it contains the correct backend connection details:
   ```bash
   GRPC_HOST=127.0.0.1
   GRPC_PORT=50051
   ```

4. (Optional) Re-generate protobuf Dart files:
   ```bash
   dart run grpc:protoc_plugin
   protoc --dart_out=grpc:lib/generated -I../protos ../protos/pose.proto
   protoc --dart_out=grpc:lib/generated -I../protos ../protos/relighting.proto
   ```

5. Run on your target platform:
   ```bash
   flutter run
   ```
`
### Testing Communication

Ensure both backend and frontend are running on the same network. Configure the backend URL in the frontend:

**Troubleshooting:**
- **Android Emulator:** If the app fails to connect, verify you are using 10.0.2.2 as the GRPC_HOST in your .env file. 127.0.0.1 will not work inside the Android emulator.
- **iOS Simulator:** Ensure you are using 127.0.0.1. If prompted, ensure you have "Local Network" permissions enabled.
- **Physical Android or iOS Device:** Use the actual Local IP address (e.g., 192.168.1.x) of the machine running the backend server. Ensure your computer and device are on the same Wi-Fi network.
