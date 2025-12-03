#!/bin/bash
set -e

PROTO_DIR="protos"
PYTHON_OUT_DIR="backend"
DART_OUT_DIR="frontend/lib/generated" 

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

echo "Generating gRPC Dart files..."

if ! command -v protoc-gen-dart &> /dev/null; then
    echo "Please run: dart pub global activate protoc_plugin"
    echo "And ensure ~/.pub-cache/bin is in your PATH."
    exit 1
fi

mkdir -p $DART_OUT_DIR

python3 -m grpc_tools.protoc \
    -I $PROTO_DIR \
    --plugin=protoc-gen-dart=$(which protoc-gen-dart) \
    --dart_out=grpc:$DART_OUT_DIR \
    $PROTO_DIR/*.proto

echo "Success! Files generated:"
echo "Python: $PYTHON_OUT_DIR"
echo "Dart:   $DART_OUT_DIR"