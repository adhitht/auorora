import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class MIGANInpaintingService {
  static const String _modelAssetPath =
      'assets/models/migan_pipeline_v2.onnx';
  static const int _inputSize = 512;

  static const int _dilateSize = 7;
  static const int _blurSize = 21;

  OrtSession? _session;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      
      // Copy asset to a temporary file because ONNX Runtime usually needs a file path
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/migan_pipeline_v2.onnx');
      if (!await tempFile.exists()) {
        final byteData = await rootBundle.load(_modelAssetPath);
        await tempFile.writeAsBytes(byteData.buffer.asUint8List(
            byteData.offsetInBytes, byteData.lengthInBytes));
      }

      _session = OrtSession.fromFile(tempFile, sessionOptions);
      _isInitialized = true;
      debugPrint('MIGANInpaintingService: Initialized successfully');
    } catch (e) {
      debugPrint('MIGANInpaintingService: Failed to load model: $e');
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
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      final orientedImage = img.bakeOrientation(decodedImage);
      final originalW = orientedImage.width;
      final originalH = orientedImage.height;

      final resizedImage = img.copyResize(
        orientedImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          'MIGANInpaintingService: Original ${originalW}x$originalH, resized to ${resizedImage.width}x${resizedImage.height}');

      final maskImage = img.Image.fromBytes(
        width: _inputSize,
        height: _inputSize,
        bytes: maskBytes.buffer,
        numChannels: 1,
      );

      final maskRaw = List.generate(
        _inputSize,
        (y) => List<double>.filled(_inputSize, 0.0),
      );
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final v = maskImage.getPixel(x, y).r;
          maskRaw[y][x] = v > 128 ? 1.0 : 0.0;
        }
      }

      final softMask = _processMask(maskRaw,
          dilateSize: _dilateSize, blurSize: _blurSize);

      // Prepare inputs for ONNX Runtime
      // Shape: [1, 3, 512, 512] for image, [1, 1, 512, 512] for mask
      final inputImageFloats = Float32List(1 * 3 * _inputSize * _inputSize);
      final inputMaskFloats = Float32List(1 * 1 * _inputSize * _inputSize);

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);
          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;
          
          // NCHW layout
          inputImageFloats[0 * _inputSize * _inputSize + y * _inputSize + x] = r;
          inputImageFloats[1 * _inputSize * _inputSize + y * _inputSize + x] = g;
          inputImageFloats[2 * _inputSize * _inputSize + y * _inputSize + x] = b;

          inputMaskFloats[0 * _inputSize * _inputSize + y * _inputSize + x] = softMask[y][x];
        }
      }

      final inputOrt = OrtValueTensor.createTensorWithDataList(
          inputImageFloats, [1, 3, _inputSize, _inputSize]);
      final maskOrt = OrtValueTensor.createTensorWithDataList(
          inputMaskFloats, [1, 1, _inputSize, _inputSize]);

      final runOptions = OrtRunOptions();
      final inputs = {'image': inputOrt, 'mask': maskOrt};
      
      final outputs = _session!.run(runOptions, inputs);
      
      inputOrt.release();
      maskOrt.release();
      runOptions.release();

      debugPrint('MIGANInpaintingService: Inference run complete');

      final outputOrt = outputs[0];
      if (outputOrt == null) throw Exception("No output from model");
      
      final rawOutput = (outputOrt as OrtValueTensor).value;
      
      final outputImage = img.Image(width: _inputSize, height: _inputSize);

      final batch0 = (rawOutput as List)[0] as List;
      final rChannel = batch0[0] as List;
      final gChannel = batch0[1] as List;
      final bChannel = batch0[2] as List;

      for (int y = 0; y < _inputSize; y++) {
        final rRow = rChannel[y] as List;
        final gRow = gChannel[y] as List;
        final bRow = bChannel[y] as List;

        for (int x = 0; x < _inputSize; x++) {
          final r = rRow[x] as double;
          final g = gRow[x] as double;
          final b = bRow[x] as double;

          outputImage.setPixelRgb(
            x,
            y,
            (r * 255).clamp(0, 255).toInt(),
            (g * 255).clamp(0, 255).toInt(),
            (b * 255).clamp(0, 255).toInt(),
          );
        }
      }
      
      for (var element in outputs) {
        element?.release();
      }

      final inpaintedResized = img.copyResize(
        outputImage,
        width: originalW,
        height: originalH,
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          'MIGANInpaintingService: Inference took ${DateTime.now().difference(startTime).inMilliseconds}ms');

      return Uint8List.fromList(img.encodePng(inpaintedResized));
    } catch (e) {
      debugPrint('MIGANInpaintingService: Error during inpainting: $e');
      return null;
    }
  }

  List<List<double>> _processMask(
    List<List<double>> mask,
    {required int dilateSize,
    required int blurSize}) {
    final dilated = _dilateMask(mask, dilateSize);
    final blurred = _gaussianBlurMask(dilated, blurSize);
    final h = blurred.length;
    final w = blurred[0].length;

    final softMask =
        List.generate(h, (y) => List<double>.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        softMask[y][x] = blurred[y][x] > 0.2 ? 1.0 : 0.0;
      }
    }

    return softMask;
  }

  List<List<double>> _dilateMask(
      List<List<double>> src, int kernelSize) {
    final h = src.length;
    final w = src[0].length;
    final r = kernelSize ~/ 2;

    final dst = List.generate(
      h,
      (_) => List<double>.filled(w, 0.0),
    );

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double maxVal = 0.0;
        for (int ky = -r; ky <= r; ky++) {
          for (int kx = -r; kx <= r; kx++) {
            final yy = (y + ky).clamp(0, h - 1);
            final xx = (x + kx).clamp(0, w - 1);
            if (src[yy][xx] > maxVal) {
              maxVal = src[yy][xx];
              if (maxVal == 1.0) break;
            }
          }
        }
        dst[y][x] = maxVal;
      }
    }

    return dst;
  }

  List<List<double>> _gaussianBlurMask(
      List<List<double>> src, int kernelSize) {
    final h = src.length;
    final w = src[0].length;

    if (kernelSize <= 1) return src;

    final radius = kernelSize ~/ 2;
    final kernel = _gaussianKernel1D(radius);

    final tmp = List.generate(
      h,
      (_) => List<double>.filled(w, 0.0),
    );
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0.0;
        for (int k = -radius; k <= radius; k++) {
          final xx = (x + k).clamp(0, w - 1);
          sum += src[y][xx] * kernel[k + radius];
        }
        tmp[y][x] = sum;
      }
    }

    final dst = List.generate(
      h,
      (_) => List<double>.filled(w, 0.0),
    );
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0.0;
        for (int k = -radius; k <= radius; k++) {
          final yy = (y + k).clamp(0, h - 1);
          sum += tmp[yy][x] * kernel[k + radius];
        }
        dst[y][x] = sum;
      }
    }

    return dst;
  }

  List<double> _gaussianKernel1D(int radius) {
    if (radius <= 0) return [1.0];
    final size = radius * 2 + 1;
    final kernel = List<double>.filled(size, 0.0);
    final sigma = radius / 2.0;
    final twoSigma2 = 2 * sigma * sigma;

    double sum = 0.0;
    for (int i = 0; i < size; i++) {
      final x = i - radius;
      final v = (sigma == 0)
          ? 1.0
          : (-(x * x) / twoSigma2).exp();
      kernel[i] = v;
      sum += v;
    }

    for (int i = 0; i < size; i++) {
      kernel[i] /= sum;
    }

    return kernel;
  }

  void dispose() {
    _session?.release();
    _isInitialized = false;
  }
}

extension on num {
  double exp() => math.exp(toDouble());
}
