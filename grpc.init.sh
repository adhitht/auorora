#!/bin/bash
set -e

PROTO_DIR="protos"
OUT_DIR="app"

echo "Generating gRPC Python files..."

mkdir -p $OUT_DIR

python -m grpc_tools.protoc \
    -I $PROTO_DIR \
    --python_out=$OUT_DIR \
    --grpc_python_out=$OUT_DIR \
    $PROTO_DIR/relighting.proto

# "import relighting_pb2 as ..."  ->  "from . import relighting_pb2 as ..."
sed -i 's/import relighting_pb2 as/from . import relighting_pb2 as/g' $OUT_DIR/relighting_pb2_grpc.py

echo "Generated and patched files in: $OUT_DIR"