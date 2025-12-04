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

#details of the submission repo
OWNER="adhitht"
REPO="adobe"
TAG="ipynbs"
ASSET_NAME="Copy_of_Relight_pipe.1.ipynb"
TOKEN="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"

# 2. Fetch release JSON to find asset ID
ASSET_ID=$(curl -s \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/${TAG}" \
  | jq -r ".assets[] | select(.name==\"${ASSET_NAME}\") | .id")


# 3. go to the correct directory
cd backend/ml_models/relighting


# 4. Download the asset using its ID
curl -L \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/octet-stream" \
  "https://api.github.com/repos/${OWNER}/${REPO}/releases/assets/${ASSET_ID}" \
  -o "${ASSET_NAME}"

# 5. Unzip the model weights
unzip -q neural_gaffer_res256_ckpt.zip

# 6. Clean up
rm -f neural_gaffer_res256_ckpt.zip



