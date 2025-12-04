import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class InpaintingService {
  static const String _modelAssetPath =
      'assets/models/lama_dilated/LaMa-Dilated_float.tflite';
  static const int _inputSize = 512;

  static const int _dilateSize = 7;
  static const int _blurSize = 21;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final options = InterpreterOptions();

      if (Platform.isAndroid) {
        options.addDelegate(GpuDelegateV2());
      } else if (Platform.isIOS) {
        options.addDelegate(GpuDelegate());
      }

      _interpreter = await Interpreter.fromAsset(
        _modelAssetPath,
        options: options,
      );
      _isInitialized = true;

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      debugPrint(
          'InpaintingService: Inputs: ${inputTensors.map((e) => e.shape).toList()}');
      debugPrint(
          'InpaintingService: Outputs: ${outputTensors.map((e) => e.shape).toList()}');
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
          'InpaintingService: Original ${originalW}x$originalH, resized to ${resizedImage.width}x${resizedImage.height}');

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

      final inputImage = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(
            _inputSize,
            (_) => List<double>.filled(3, 0.0),
          ),
        ),
      );

      final inputMask = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(
            _inputSize,
            (_) => List<double>.filled(1, 0.0),
          ),
        ),
      );

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);

          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;

          final m = softMask[y][x];

          inputImage[0][y][x][0] = r;
          inputImage[0][y][x][1] = g;
          inputImage[0][y][x][2] = b;

          inputMask[0][y][x][0] = m;
        }
      }

      final outputBuffer = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(
            _inputSize,
            (_) => List<double>.filled(3, 0.0),
          ),
        ),
      );

      final inputs = [inputImage, inputMask];
      final outputs = {0: outputBuffer};

      _interpreter!.runForMultipleInputs(inputs, outputs);
      debugPrint('InpaintingService: Inference run complete');

      final outputImage = img.Image(width: _inputSize, height: _inputSize);

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final r = outputBuffer[0][y][x][0];
          final g = outputBuffer[0][y][x][1];
          final b = outputBuffer[0][y][x][2];

          outputImage.setPixelRgb(
            x,
            y,
            (r * 255).clamp(0, 255).toInt(),
            (g * 255).clamp(0, 255).toInt(),
            (b * 255).clamp(0, 255).toInt(),
          );
        }
      }

      final inpaintedResized = img.copyResize(
        outputImage,
        width: originalW,
        height: originalH,
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          'InpaintingService: Inference took ${DateTime.now().difference(startTime).inMilliseconds}ms');

      return Uint8List.fromList(img.encodePng(inpaintedResized));
    } catch (e) {
      debugPrint('InpaintingService: Error during inpainting: $e');
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
    _interpreter?.close();
    _isInitialized = false;
  }
}

extension on num {
  double exp() => math.exp(toDouble());
}
