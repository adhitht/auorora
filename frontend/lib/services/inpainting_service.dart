import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InpaintingService {
  static const String _modelPath = 'assets/models/LaMa-Dilated_float.tflite';
  static const int _inputSize = 512;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _isInitialized = true;
      debugPrint('InpaintingService: Model loaded successfully');
      
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      debugPrint('Inpainting Inputs:');
      for (var t in inputTensors) {
        debugPrint('  ${t.name}: ${t.shape} ${t.type}');
      }
    } catch (e) {
      debugPrint('InpaintingService: Failed to load model: $e');
      rethrow;
    }
  }

  Future<Uint8List?> inpaint(
    File imageFile, 
    Uint8List maskBytes,
  ) async {
    if (!_isInitialized) await initialize();

    try {
      final startTime = DateTime.now();
      
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final orientedImage = img.bakeOrientation(image);
      final originalW = orientedImage.width;
      final originalH = orientedImage.height;

      double scale = 1.0;
      if (originalW > originalH) {
        scale = _inputSize / originalW;
      } else {
        scale = _inputSize / originalH;
      }

      final targetW = (originalW * scale).round();
      final targetH = (originalH * scale).round();

      debugPrint('InpaintingService: Original ${originalW}x${originalH}, Target ${targetW}x${targetH}');

      final resizedImage = img.copyResize(
        orientedImage,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );

      // 2. Prepare Mask
      // Mask comes in as 512x512 stretched. We need to un-stretch it to match image aspect ratio.
      // Or better: The mask corresponds to the STRETCHED image (from SegmentationService).
      // If we want to apply it to the PADDED image, we need to transform it.
      // The easiest way is to treat the mask as an image, resize it to targetW x targetH.
      // But wait, the mask input `maskBytes` is 512x512.
      // If we resize 512x512 (stretched) -> targetW x targetH (aspect correct),
      // we are effectively un-stretching it. This is correct.
      
      final maskImage = img.Image.fromBytes(
        width: _inputSize,
        height: _inputSize,
        bytes: maskBytes.buffer,
        numChannels: 1,
      );
      
      final resizedMask = img.copyResize(
        maskImage,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );

      // We'll center the image and mask in the 512x512 canvas
      final padX = (_inputSize - targetW) ~/ 2;
      final padY = (_inputSize - targetH) ~/ 2;

      final inputImage = List.generate(
        1,
        (b) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              // Check if inside the valid image area
              if (x >= padX && x < padX + targetW && y >= padY && y < padY + targetH) {
                final pixel = resizedImage.getPixel(x - padX, y - padY);
                return [
                  pixel.r / 255.0,
                  pixel.g / 255.0,
                  pixel.b / 255.0,
                ];
              }
              // Padding (Grey or Black? LaMa usually handles 0 ok, or we can replicate edge)
              // Let's use 0.5 (grey) or 0.0. 
              return [0.5, 0.5, 0.5]; 
            },
          ),
        ),
      );

      final inputMask = List.generate(
        1,
        (b) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              if (x >= padX && x < padX + targetW && y >= padY && y < padY + targetH) {
                 final pixel = resizedMask.getPixel(x - padX, y - padY);
                 // Mask: > 127 is object (1.0), else 0.0
                 return [pixel.r > 127 ? 1.0 : 0.0];
              }
              // Padding area should NOT be masked (0.0) so it's kept as is?
              // Or should it be masked? No, we don't want to inpaint the padding.
              return [0.0];
            },
          ),
        ),
      );

      // Run Inference
      final outputBuffer = List.filled(1 * _inputSize * _inputSize * 3, 0.0).reshape([1, _inputSize, _inputSize, 3]);
      
      _interpreter!.runForMultipleInputs([inputImage, inputMask], {0: outputBuffer});
      debugPrint('InpaintingService: Inference run complete');

      // Process Output
      // We need to extract the valid area (targetW x targetH) from the center
      final outputImage = img.Image(width: targetW, height: targetH);
      final outData = outputBuffer[0] as List<List<List<double>>>;

      for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
          final pixel = outData[y + padY][x + padX];
          outputImage.setPixelRgb(
            x,
            y,
            (pixel[0] * 255).clamp(0, 255).toInt(),
            (pixel[1] * 255).clamp(0, 255).toInt(),
            (pixel[2] * 255).clamp(0, 255).toInt(),
          );
        }
      }

      debugPrint('InpaintingService: Output extracted, resizing to original ${originalW}x${originalH}');
      
      final inpaintedResized = img.copyResize(
        outputImage,
        width: originalW,
        height: originalH,
        interpolation: img.Interpolation.linear,
      );

      // Composite back onto original to preserve quality
      // We need the mask at original resolution
      // The mask we used for inference was 'resizedMask' (targetW x targetH)
      // We need to resize that to originalW x originalH, or just resize the original 512 mask.
      // Let's resize the 512 input mask to original size.
      
      final fullSizeMask = img.copyResize(
        img.Image.fromBytes(
          width: _inputSize,
          height: _inputSize,
          bytes: maskBytes.buffer,
          numChannels: 1,
        ),
        width: originalW,
        height: originalH,
        interpolation: img.Interpolation.linear,
      );

      debugPrint('InpaintingService: Compositing with original image...');
      
      // Blend: If mask > threshold, use inpainted, else original
      for (int y = 0; y < originalH; y++) {
        for (int x = 0; x < originalW; x++) {
          final maskVal = fullSizeMask.getPixel(x, y).r;
          if (maskVal > 100) { // Threshold
             // Use inpainted
             // inpaintedResized is already set
          } else {
             // Use original
             final origPixel = orientedImage.getPixel(x, y);
             inpaintedResized.setPixel(x, y, origPixel);
          }
        }
      }

      debugPrint('InpaintingService: Inference took ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      return Uint8List.fromList(img.encodePng(inpaintedResized));

    } catch (e) {
      debugPrint('InpaintingService: Error during inpainting: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
