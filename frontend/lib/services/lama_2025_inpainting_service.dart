import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class Lama2025InpaintingService {
  static const String _modelAssetPath =
      'assets/models/inpainting_lama_2025jan.onnx';

  static const int _inputSize = 512;
  static const int _dilateSize = 7;
  static const int _blurSize = 21;

  OrtSession? _session;
  bool _isInitialized = false;

  // ===========================================================
  // INITIALIZE MODEL
  // ===========================================================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OrtEnv.instance.init();
      final opts = OrtSessionOptions();

      final tmp = await getTemporaryDirectory();
      final modelFile = File("${tmp.path}/lama_2025.onnx");

      if (!await modelFile.exists()) {
        final raw = await rootBundle.load(_modelAssetPath);
        await modelFile.writeAsBytes(
          raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        );
      }

      _session = OrtSession.fromFile(modelFile, opts);
      opts.release();

      _isInitialized = true;
      debugPrint("Lama2025InpaintingService -> Initialized");
    } catch (e) {
      debugPrint("Lama2025 init ERROR: $e");
      rethrow;
    }
  }

  // ===========================================================
  // RUN INPAINT
  // ===========================================================

  Future<Uint8List?> inpaint(File imageFile, Uint8List maskBytes) async {
    if (!_isInitialized) await initialize();

    final T0 = DateTime.now();

    try {
      // ---- Load & Resize Image ----
      final imgBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(imgBytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);
      final origW = oriented.width;
      final origH = oriented.height;

      final resized = img.copyResize(
        oriented,
        width: _inputSize,
        height: _inputSize,
      );

      // ---- Decode Mask ----
      final maskImage = img.Image.fromBytes(
        width: _inputSize,
        height: _inputSize,
        bytes: maskBytes.buffer,
        numChannels: 1,
      );

      final maskMatrix = List.generate(
        _inputSize,
        (y) => List<double>.filled(_inputSize, 0.0),
      );

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          maskMatrix[y][x] = maskImage.getPixel(x, y).r / 255.0;
        }
      }

      final softMask = _processMask(maskMatrix);

      // ---- Build NCHW Input ----

      final imageTensor =
          Float32List(1 * 3 * _inputSize * _inputSize);

      final maskTensor =
          Float32List(1 * 1 * _inputSize * _inputSize);

      int idx(int c, int y, int x) =>
          c * _inputSize * _inputSize + y * _inputSize + x;

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final px = resized.getPixel(x, y);

          imageTensor[idx(0, y, x)] = px.r / 255.0; // R
          imageTensor[idx(1, y, x)] = px.g / 255.0; // G
          imageTensor[idx(2, y, x)] = px.b / 255.0; // B

          maskTensor[y * _inputSize + x] = softMask[y][x];
        }
      }

      final ortImg = OrtValueTensor.createTensorWithDataList(
          imageTensor, [1, 3, _inputSize, _inputSize]);

      final ortMask = OrtValueTensor.createTensorWithDataList(
          maskTensor, [1, 1, _inputSize, _inputSize]);

      final runOpts = OrtRunOptions();

      // ---- Dynamic Input Names ----

      final inputs = _session!.inputNames;
      final imgName = inputs.firstWhere(
        (e) => e.contains("image") || e.contains("input"),
        orElse: () => inputs[0],
      );
      final maskName = inputs.firstWhere(
        (e) => e.contains("mask"),
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
      final outValue = outTensor.value; // <-- nested list

      outTensor.release();
      for (var o in outputs) {
        o?.release();
      }

      // ===========================================================
      // HANDLE NESTED LIST OUTPUT
      // ===========================================================

      // output shape = [1][3][H][W]
      final batch = outValue as List;
      final cList = batch[0] as List;

      final rChan = cList[0] as List; // List<List<double>>
      final gChan = cList[1] as List;
      final bChan = cList[2] as List;

      final outImg =
          img.Image(width: _inputSize, height: _inputSize);

      for (int y = 0; y < _inputSize; y++) {
        final rRow = rChan[y] as List;
        final gRow = gChan[y] as List;
        final bRow = bChan[y] as List;

        for (int x = 0; x < _inputSize; x++) {
          outImg.setPixelRgb(
            x,
            y,
            (rRow[x] * 255).clamp(0, 255).toInt(),
            (gRow[x] * 255).clamp(0, 255).toInt(),
            (bRow[x] * 255).clamp(0, 255).toInt(),
          );
        }
      }

      // ---- Resize back to original ----
      final restored = img.copyResize(
        outImg,
        width: origW,
        height: origH,
      );

      debugPrint(
          "Inpaint OK: ${DateTime.now().difference(T0).inMilliseconds} ms");

      return Uint8List.fromList(img.encodePng(restored));
    } catch (e) {
      debugPrint("Inpaint ERROR: $e");
      return null;
    }
  }

  // ===========================================================
  // MASK PROCESSING
  // ===========================================================

  List<List<double>> _processMask(List<List<double>> mask) {
    final d = _dilateMask(mask, _dilateSize);
    return _gaussianBlurMask(d, _blurSize);
  }

  List<List<double>> _dilateMask(List<List<double>> src, int k) {
    final h = src.length, w = src[0].length;
    final r = k ~/ 2;

    final out = List.generate(h, (_) => List<double>.filled(w, 0));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double maxv = 0;
        for (int dy = -r; dy <= r; dy++) {
          for (int dx = -r; dx <= r; dx++) {
            final yy = (y + dy).clamp(0, h - 1);
            final xx = (x + dx).clamp(0, w - 1);
            maxv = math.max(maxv, src[yy][xx]);
          }
        }
        out[y][x] = maxv;
      }
    }
    return out;
  }

  List<List<double>> _gaussianBlurMask(List<List<double>> src, int size) {
    if (size <= 1) return src;

    final h = src.length;
    final w = src[0].length;

    final r = size ~/ 2;
    final kernel = _gaussianKernel1D(r);

    final tmp = List.generate(h, (_) => List<double>.filled(w, 0));
    final out = List.generate(h, (_) => List<double>.filled(w, 0));

    // horizontal
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double s = 0;
        for (int i = -r; i <= r; i++) {
          final xx = (x + i).clamp(0, w - 1);
          s += src[y][xx] * kernel[i + r];
        }
        tmp[y][x] = s;
      }
    }

    // vertical
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double s = 0;
        for (int i = -r; i <= r; i++) {
          final yy = (y + i).clamp(0, h - 1);
          s += tmp[yy][x] * kernel[i + r];
        }
        out[y][x] = s;
      }
    }

    return out;
  }

  List<double> _gaussianKernel1D(int r) {
    final size = 2 * r + 1;
    final sigma = r / 1.5;
    final twoSigma2 = 2 * sigma * sigma;

    final k = List<double>.filled(size, 0);
    double sum = 0;

    for (int i = 0; i < size; i++) {
      final x = i - r;
      final v = math.exp(-(x * x) / twoSigma2);
      k[i] = v;
      sum += v;
    }

    for (int i = 0; i < size; i++) {
      k[i] /= sum;
    }

    return k;
  }

  // ===========================================================
  // CLEANUP
  // ===========================================================

  void dispose() {
    _session?.release();
    _isInitialized = false;
  }
}
