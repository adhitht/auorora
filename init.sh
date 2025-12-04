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
