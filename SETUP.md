# Setup Guide

## Local Testing

### Prerequisites
- **Backend**: Python 3.12 (Tested), pip
- **Frontend**: Flutter 3.35.7 (Tested)

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
   # Android
   flutter run -d <device_id>
   
   # iOS
   flutter run -d <device_id>
   
   # Windows
   flutter run -d windows
   
   # macOS
   flutter run -d macos
   
   # Linux
   flutter run -d linux
   ```

### Testing Communication

Ensure both backend and frontend are running on the same network. Configure the backend URL in the frontend:

- Update the gRPC channel in `frontend/lib/services/` to point to your backend server
- Default: `localhost:50051` for local testing
