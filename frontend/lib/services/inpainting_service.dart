import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class InpaintingService {
  static const String _modelAssetPath = 'assets/models/lama_dilated/LaMa-Dilated_float.tflite';
  static const int _inputSize = 512;

  static const bool _enableAverageFill = true;
  static const bool _enableBlur = true;
  static const int _contextMargin = 50;
  static const int _blurRadius = 4; 

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final options = InterpreterOptions();
      // TODO: Check for better ways to optimize the model
      // Add delegate with NPU????
      if (Platform.isAndroid) options.addDelegate(GpuDelegateV2());
      if (Platform.isIOS) options.addDelegate(GpuDelegate());

      _interpreter = await Interpreter.fromAsset(_modelAssetPath, options: options);
      _isInitialized = true;
      debugPrint('InpaintingService: TFLite Model loaded successfully');
      
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      debugPrint('InpaintingService: Inputs: ${inputTensors.map((e) => e.shape).toList()}');
      debugPrint('InpaintingService: Outputs: ${outputTensors.map((e) => e.shape).toList()}');

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

      debugPrint('InpaintingService: Original ${originalW}x$originalH, Target ${targetW}x$targetH');

      final resizedImage = img.copyResize(
        orientedImage,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );

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

      // Average Color Fill
      if (_enableAverageFill) {
        int minX = targetW, minY = targetH, maxX = 0, maxY = 0;
        bool hasMask = false;

        // Find bounding box of the mask
        for (int y = 0; y < targetH; y++) {
          for (int x = 0; x < targetW; x++) {
            if (resizedMask.getPixel(x, y).r > 127) {
              hasMask = true;
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }

        if (hasMask) {
          // Expand bounding box to get context
          final contextMinX = (minX - _contextMargin).clamp(0, targetW - 1);
          final contextMaxX = (maxX + _contextMargin).clamp(0, targetW - 1);
          final contextMinY = (minY - _contextMargin).clamp(0, targetH - 1);
          final contextMaxY = (maxY + _contextMargin).clamp(0, targetH - 1);

          double totalR = 0, totalG = 0, totalB = 0;
          int count = 0;

          for (int y = contextMinY; y <= contextMaxY; y++) {
            for (int x = contextMinX; x <= contextMaxX; x++) {
              if (resizedMask.getPixel(x, y).r <= 127) {
                final pixel = resizedImage.getPixel(x, y);
                totalR += pixel.r;
                totalG += pixel.g;
                totalB += pixel.b;
                count++;
              }
            }
          }

          int avgR = 127, avgG = 127, avgB = 127;
          if (count > 0) {
            avgR = (totalR / count).round();
            avgG = (totalG / count).round();
            avgB = (totalB / count).round();
          }

          for (int y = minY; y <= maxY; y++) {
            for (int x = minX; x <= maxX; x++) {
              if (resizedMask.getPixel(x, y).r > 127) {
                resizedImage.setPixelRgb(x, y, avgR, avgG, avgB);
              }
            }
          }
        }
      }

      // Gaussian Blur
      if (_enableBlur) {
        final blurredImage = img.gaussianBlur(resizedImage, radius: _blurRadius);

        for (int y = 0; y < targetH; y++) {
          for (int x = 0; x < targetW; x++) {
            final maskVal = resizedMask.getPixel(x, y).r;
            if (maskVal > 127) {
              resizedImage.setPixel(x, y, blurredImage.getPixel(x, y));
            }
          }
        }
      }

      final padX = (_inputSize - targetW) ~/ 2;
      final padY = (_inputSize - targetH) ~/ 2;

      final inputImage = List.generate(
        1, 
        (i) => List.generate(
          _inputSize, 
          (y) => List.generate(
            _inputSize, 
            (x) => List.filled(3, 0.0),
          ),
        ),
      );

      final inputMask = List.generate(
        1, 
        (i) => List.generate(
          _inputSize, 
          (y) => List.generate(
            _inputSize, 
            (x) => List.filled(1, 0.0),
          ),
        ),
      );

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          double r = 0.5, g = 0.5, b = 0.5;
          double m = 1.0;
          
          if (x >= padX && x < padX + targetW && y >= padY && y < padY + targetH) {
            final pixel = resizedImage.getPixel(x - padX, y - padY);
            r = pixel.r / 255.0;
            g = pixel.g / 255.0;
            b = pixel.b / 255.0;
            
            final maskPixel = resizedMask.getPixel(x - padX, y - padY);
            m = maskPixel.r > 127 ? 1.0 : 0.0;
          } else {
             m = 0.0;
          }

          inputImage[0][y][x][0] = r;
          inputImage[0][y][x][1] = g;
          inputImage[0][y][x][2] = b;
          
          inputMask[0][y][x][0] = m;
        }
      }

      final outputBuffer = List.generate(
        1, 
        (i) => List.generate(
          _inputSize, 
          (y) => List.generate(
            _inputSize, 
            (x) => List.filled(3, 0.0),
          ),
        ),
      );

      final inputs = [inputImage, inputMask];
      final outputs = {0: outputBuffer};

      _interpreter!.runForMultipleInputs(inputs, outputs);
      debugPrint('InpaintingService: Inference run complete');
      
      final outputImage = img.Image(width: targetW, height: targetH);

      for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
          final r = outputBuffer[0][y + padY][x + padX][0];
          final g = outputBuffer[0][y + padY][x + padX][1];
          final b = outputBuffer[0][y + padY][x + padX][2];
          
          outputImage.setPixelRgb(
            x,
            y,
            (r * 255).clamp(0, 255).toInt(),
            (g * 255).clamp(0, 255).toInt(),
            (b * 255).clamp(0, 255).toInt(),
          );
        }
      }

      debugPrint('InpaintingService: Output extracted, resizing to original ${originalW}x$originalH');
      
      final inpaintedResized = img.copyResize(
        outputImage,
        width: originalW,
        height: originalH,
        interpolation: img.Interpolation.linear,
      );

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
      
      for (int y = 0; y < originalH; y++) {
        for (int x = 0; x < originalW; x++) {
          final maskVal = fullSizeMask.getPixel(x, y).r;
          if (maskVal > 100) { 
             final inpaintedPixel = inpaintedResized.getPixel(x, y);
             orientedImage.setPixel(x, y, inpaintedPixel);
          } else {
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
