#!/bin/bash
set -e

PROTO_DIR="protos"
PYTHON_OUT_DIR="backend"

echo "Generating gRPC Python files..."
mkdir -p $PYTHON_OUT_DIR

python3 -m grpc_tools.protoc \
    -I $PROTO_DIR \
    --python_out=$PYTHON_OUT_DIR \
    --grpc_python_out=$PYTHON_OUT_DIR \
    $PROTO_DIR/*.proto

for file in $PYTHON_OUT_DIR/*_pb2_grpc.py; do
    [ -e "$file" ] || continue
    
    sed -i -E 's/^import (.*_pb2) as/from . import \1 as/g' "$file"
done

echo "Success! Files generated:"


echo "Downloading Neural Gaffer checkpoints"
# 1. go to the correct directory
cd backend/ml_models/relighting

# 2. Download the 
wget -q https://huggingface.co/coast01/Neural_Gaffer/resolve/main/neural_gaffer_res256_ckpt.zip -O neural_gaffer_res256_ckpt.zip

# 5. Unzip the model weights
unzip -q neural_gaffer_res256_ckpt.zip

# 6. Clean up
rm -f neural_gaffer_res256_ckpt.zip



