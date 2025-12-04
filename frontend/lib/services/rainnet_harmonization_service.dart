import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class RainnetHarmonizationService {
  static const String _modelAssetPath = 'assets/models/rainnet_512_int8.onnx';

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
    }
  }

  // ===========================================================
  // RUN HARMONIZATION
  // ===========================================================

  Future<Uint8List?> harmonize(img.Image compositeImage, img.Image maskImage) async {
    if (!_isInitialized && !_initFailed) await initialize();

    if (_initFailed || !_isInitialized) {
      debugPrint("Rainnet not initialized, returning original image.");
      return Uint8List.fromList(img.encodePng(compositeImage));
    }

    final T0 = DateTime.now();

    try {
      int minX = maskImage.width;
      int minY = maskImage.height;
      int maxX = 0;
      int maxY = 0;
      bool found = false;

      for (int y = 0; y < maskImage.height; y++) {
        for (int x = 0; x < maskImage.width; x++) {
          final pixel = maskImage.getPixel(x, y);
          if (pixel.r > 128) { 
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
            found = true;
          }
        }
      }

      if (!found) {
        debugPrint("Rainnet: Empty mask, returning original.");
        return Uint8List.fromList(img.encodePng(compositeImage));
      }

      final padding = 50; 
      minX = (minX - padding).clamp(0, maskImage.width - 1);
      minY = (minY - padding).clamp(0, maskImage.height - 1);
      maxX = (maxX + padding).clamp(0, maskImage.width - 1);
      maxY = (maxY + padding).clamp(0, maskImage.height - 1);

      final cropW = maxX - minX + 1;
      final cropH = maxY - minY + 1;

      final cropImg = img.copyCrop(compositeImage, x: minX, y: minY, width: cropW, height: cropH);
      final cropMask = img.copyCrop(maskImage, x: minX, y: minY, width: cropW, height: cropH);

      final resizedImg = img.copyResize(
        cropImg,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      final resizedMask = img.copyResize(
        cropMask,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

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

          maskTensor[y * _inputSize + x] = mx.r / 255.0;
        }
      }

      final ortImg = OrtValueTensor.createTensorWithDataList(
          imageTensor, [1, 3, _inputSize, _inputSize]);

      final ortMask = OrtValueTensor.createTensorWithDataList(
          maskTensor, [1, 1, _inputSize, _inputSize]);

      final runOpts = OrtRunOptions();

      final inputs = _session!.inputNames;
      final imgName = inputs.firstWhere(
        (e) => e.toLowerCase().contains("img") || e.toLowerCase().contains("image") || e.toLowerCase().contains("input"),
        orElse: () => inputs[0],
      );
      final maskName = inputs.firstWhere(
        (e) => e.toLowerCase().contains("mask"),
        orElse: () => inputs.length > 1 ? inputs[1] : inputs[0],
      );

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

      final restoredCrop = img.copyResize(
        outImg,
        width: cropW,
        height: cropH,
        interpolation: img.Interpolation.linear,
      );

      for (int y = 0; y < cropH; y++) {
        for (int x = 0; x < cropW; x++) {
          final globalX = minX + x;
          final globalY = minY + y;
          
          final maskVal = maskImage.getPixel(globalX, globalY).r / 255.0;
          
          if (maskVal > 0.01) {
            final newPx = restoredCrop.getPixel(x, y);
            final oldPx = compositeImage.getPixel(globalX, globalY);
            
            final r = (newPx.r * maskVal + oldPx.r * (1 - maskVal)).round();
            final g = (newPx.g * maskVal + oldPx.g * (1 - maskVal)).round();
            final b = (newPx.b * maskVal + oldPx.b * (1 - maskVal)).round();
            
            compositeImage.setPixelRgb(globalX, globalY, r, g, b);
          }
        }
      }

      debugPrint(
          "Harmonization OK: ${DateTime.now().difference(T0).inMilliseconds} ms");

      return Uint8List.fromList(img.encodePng(compositeImage));
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
