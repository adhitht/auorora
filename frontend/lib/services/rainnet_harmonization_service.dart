import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class RainnetHarmonizationService {
  static const String _modelAssetPath = 'assets/models/rainnet_512.onnx';

  static const int _inputSize = 512;

  OrtSession? _session;
  bool _isInitialized = false;
  bool _initFailed = false;

  // ===========================================================
  // INITIALIZE MODEL
  // ===========================================================

  Future<void> initialize() async {
    if (_isInitialized || _initFailed) return;

    try {
      OrtEnv.instance.init();
      final opts = OrtSessionOptions();
      try {
        opts.setSessionGraphOptimizationLevel(
            GraphOptimizationLevel.ortDisableAll);
      } catch (e) {
        debugPrint("Could not set optimization level: $e");
      }

      final tmp = await getTemporaryDirectory();
      final modelFile = File("${tmp.path}/rainnet_512_int8.onnx");

      if (!await modelFile.exists()) {
        final raw = await rootBundle.load(_modelAssetPath);
        await modelFile.writeAsBytes(
          raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        );
      }

      _session = OrtSession.fromFile(modelFile, opts);
      opts.release();

      _isInitialized = true;
      debugPrint("RainnetHarmonizationService -> Initialized");
    } catch (e) {
      debugPrint("Rainnet init ERROR: $e");
      _initFailed = true;
      // Do not rethrow, just mark as failed.
    }
  }

  // ===========================================================
  // RUN HARMONIZATION
  // ===========================================================

  /// [compositeImage] is the full image with the object pasted on it.
  /// [maskImage] is the full image mask (white = object, black = background).
  Future<Uint8List?> harmonize(img.Image compositeImage, img.Image maskImage) async {
    if (!_isInitialized && !_initFailed) await initialize();

    if (_initFailed || !_isInitialized) {
      debugPrint("Rainnet not initialized, returning original image.");
      return Uint8List.fromList(img.encodePng(compositeImage));
    }

    final T0 = DateTime.now();

    try {
      final origW = compositeImage.width;
      final origH = compositeImage.height;

      // ---- Resize to Model Input Size ----
      final resizedImg = img.copyResize(
        compositeImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      final resizedMask = img.copyResize(
        maskImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      // ---- Build NCHW Input ----
      // RainNet typically expects:
      // Image: 1x3x512x512, normalized 0..1
      // Mask: 1x1x512x512, 0..1

      final imageTensor = Float32List(1 * 3 * _inputSize * _inputSize);
      final maskTensor = Float32List(1 * 1 * _inputSize * _inputSize);

      int idx(int c, int y, int x) =>
          c * _inputSize * _inputSize + y * _inputSize + x;

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final px = resizedImg.getPixel(x, y);
          final mx = resizedMask.getPixel(x, y);

          // Normalize 0.0 to 1.0
          imageTensor[idx(0, y, x)] = px.r / 255.0;
          imageTensor[idx(1, y, x)] = px.g / 255.0;
          imageTensor[idx(2, y, x)] = px.b / 255.0;

          // Mask is single channel
          maskTensor[y * _inputSize + x] = mx.r / 255.0;
        }
      }

      final ortImg = OrtValueTensor.createTensorWithDataList(
          imageTensor, [1, 3, _inputSize, _inputSize]);

      final ortMask = OrtValueTensor.createTensorWithDataList(
          maskTensor, [1, 1, _inputSize, _inputSize]);

      final runOpts = OrtRunOptions();

      // ---- Dynamic Input Names ----
      final inputs = _session!.inputNames;
      // Usually "images" and "masks" or "input" and "mask"
      final imgName = inputs.firstWhere(
        (e) => e.toLowerCase().contains("img") || e.toLowerCase().contains("image") || e.toLowerCase().contains("input"),
        orElse: () => inputs[0],
      );
      final maskName = inputs.firstWhere(
        (e) => e.toLowerCase().contains("mask"),
        orElse: () => inputs.length > 1 ? inputs[1] : inputs[0],
      );

      // ---- Run Model ----
      final outputs = _session!.run(runOpts, {
        imgName: ortImg,
        maskName: ortMask,
      });

      ortImg.release();
      ortMask.release();
      runOpts.release();

      final outTensor = outputs[0] as OrtValueTensor;
      final outValue = outTensor.value;

      // ===========================================================
      // HANDLE OUTPUT
      // ===========================================================

      // output shape = [1][3][H][W]
      final batch = outValue as List;
      final cList = batch[0] as List;

      final rChan = cList[0] as List;
      final gChan = cList[1] as List;
      final bChan = cList[2] as List;

      final outImg = img.Image(width: _inputSize, height: _inputSize);

      for (int y = 0; y < _inputSize; y++) {
        final rRow = rChan[y] as List;
        final gRow = gChan[y] as List;
        final bRow = bChan[y] as List;

        for (int x = 0; x < _inputSize; x++) {
          double r = (rRow[x] as num).toDouble();
          double g = (gRow[x] as num).toDouble();
          double b = (bRow[x] as num).toDouble();

          // Assuming 0..1 output. If negative or >1, clamp.
          // Some models output -1..1, but usually 0..1.
          // We can check range if needed, but clamping is safe.
          
          outImg.setPixelRgb(
            x,
            y,
            (r * 255).clamp(0, 255).toInt(),
            (g * 255).clamp(0, 255).toInt(),
            (b * 255).clamp(0, 255).toInt(),
          );
        }
      }

      outTensor.release();
      for (var o in outputs) {
        o?.release();
      }

      // ---- Resize back to original ----
      final restored = img.copyResize(
        outImg,
        width: origW,
        height: origH,
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          "Harmonization OK: ${DateTime.now().difference(T0).inMilliseconds} ms");

      return Uint8List.fromList(img.encodePng(restored));
    } catch (e) {
      debugPrint("Harmonization ERROR: $e");
      return null;
    }
  }

  void dispose() {
    _session?.release();
    _isInitialized = false;
  }
}
