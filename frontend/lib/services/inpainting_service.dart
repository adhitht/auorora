import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class InpaintingService {
  static const String _modelAssetPath = 'assets/models/migan_pipeline_v2.onnx';
  static const int _inputSize = 512;

  OrtSession? _session;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OrtEnv.instance.init();
      
      // Copy asset to temp file because ONNX Runtime usually needs a file path
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/migan_model.onnx');
      
      if (!await modelFile.exists()) {
        debugPrint('InpaintingService: Copying model to ${modelFile.path}...');
        final byteData = await rootBundle.load(_modelAssetPath);
        await modelFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(modelFile, sessionOptions);
      _isInitialized = true;
      debugPrint('InpaintingService: ONNX Model loaded successfully');
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
      
      // 1. Prepare Image
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final orientedImage = img.bakeOrientation(image);
      final originalW = orientedImage.width;
      final originalH = orientedImage.height;

      // Calculate scale to fit in 512x512 maintaining aspect ratio
      double scale = 1.0;
      if (originalW > originalH) {
        scale = _inputSize / originalW;
      } else {
        scale = _inputSize / originalH;
      }

      final targetW = (originalW * scale).round();
      final targetH = (originalH * scale).round();

      debugPrint('InpaintingService: Original ${originalW}x$originalH, Target ${targetW}x$targetH');

      // Resize image to fit
      final resizedImage = img.copyResize(
        orientedImage,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );

      // 2. Prepare Mask
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

      // 3. Create Padded Inputs (512x512)
      final padX = (_inputSize - targetW) ~/ 2;
      final padY = (_inputSize - targetH) ~/ 2;

      // Prepare Float32 Lists for ONNX
      // Shape: [1, 3, 512, 512] for image
      // Shape: [1, 1, 512, 512] for mask
      
      final Float32List imageFloatList = Float32List(1 * 3 * _inputSize * _inputSize);
      final Float32List maskFloatList = Float32List(1 * 1 * _inputSize * _inputSize);

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          double r = 0.5, g = 0.5, b = 0.5; // Padding
          double m = 0.0; // Mask padding (0 = valid)

          if (x >= padX && x < padX + targetW && y >= padY && y < padY + targetH) {
            final pixel = resizedImage.getPixel(x - padX, y - padY);
            // Normalize to 0..1
            r = pixel.r / 255.0;
            g = pixel.g / 255.0;
            b = pixel.b / 255.0;
            
            final maskPixel = resizedMask.getPixel(x - padX, y - padY);
            // Mask: 1 for hole, 0 for valid
            m = maskPixel.r > 127 ? 1.0 : 0.0;
          }

          // NCHW layout
          // Image
          imageFloatList[0 * _inputSize * _inputSize + y * _inputSize + x] = r;
          imageFloatList[1 * _inputSize * _inputSize + y * _inputSize + x] = g;
          imageFloatList[2 * _inputSize * _inputSize + y * _inputSize + x] = b;
          
          // Mask
          maskFloatList[0 * _inputSize * _inputSize + y * _inputSize + x] = m;
        }
      }

      // Create Tensors
      final imageTensor = OrtValueTensor.createTensorWithDataList(
        imageFloatList,
        [1, 3, _inputSize, _inputSize],
      );
      
      final maskTensor = OrtValueTensor.createTensorWithDataList(
        maskFloatList,
        [1, 1, _inputSize, _inputSize],
      );

      // Run Inference
      final runOptions = OrtRunOptions();
      
      // Using standard names 'img' and 'mask' based on common MI-GAN exports
      final inputs = {
        'image': imageTensor,
        'mask': maskTensor,
      };
      
      final outputs = _session!.run(runOptions, inputs);
      debugPrint('InpaintingService: Inference run complete');
      
      // Process Output
      final outputTensor = outputs[0];
      if (outputTensor == null) throw Exception('No output produced');
      
      // Handle output - assuming it returns the structured list [1][3][512][512]
      final outputList = outputTensor.value as List<List<List<List<double>>>>; 
      final outBatch = outputList[0]; // [3][512][512]
      
      final outputImage = img.Image(width: targetW, height: targetH);

      for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
          double r = outBatch[0][y + padY][x + padX];
          double g = outBatch[1][y + padY][x + padX];
          double b = outBatch[2][y + padY][x + padX];
          
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

      // Composite back onto original
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
             // Use inpainted
          } else {
             // Use original
             final origPixel = orientedImage.getPixel(x, y);
             inpaintedResized.setPixel(x, y, origPixel);
          }
        }
      }

      debugPrint('InpaintingService: Inference took ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      // Cleanup
      imageTensor.release();
      maskTensor.release();
      outputTensor.release();
      runOptions.release();
      
      return Uint8List.fromList(img.encodePng(inpaintedResized));

    } catch (e) {
      debugPrint('InpaintingService: Error during inpainting: $e');
      return null;
    }
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}
