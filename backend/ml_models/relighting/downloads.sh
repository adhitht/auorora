#!/bin/bash

echo ">>> Downloading Neural Gaffer checkpoint..."
wget -q https://huggingface.co/coast01/Neural_Gaffer/resolve/main/neural_gaffer_res256_ckpt.zip -O neural_gaffer_res256_ckpt.zip

echo ">>> Unzipping checkpoint..."
unzip -q neural_gaffer_res256_ckpt.zip

echo ">>> Cleaning up..."
rm -f neural_gaffer_res256_ckpt.zip
