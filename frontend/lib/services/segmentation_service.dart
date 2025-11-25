import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class SegmentationResult {
  final Uint8List mask;
  final int width;
  final int height;
  final int validWidth;
  final int validHeight;
  final double inferenceTime;

  SegmentationResult({
    required this.mask,
    required this.width,
    required this.height,
    required this.validWidth,
    required this.validHeight,
    required this.inferenceTime,
  });
}

class CutoutResult {
  final Uint8List imageBytes;
  final int x;
  final int y;
  final int width;
  final int height;

  CutoutResult({
    required this.imageBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class SegmentationService {
  static const String _modelPath = 'assets/models/magic_touch.tflite';

  static const int _inputSize = 512;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Uint8List? _cachedMask;
  int _maskWidth = 0;
  int _maskHeight = 0;

  int _originalWidth = 0;
  int _originalHeight = 0;

  img.Image? _cachedImage;

  List<List<List<List<double>>>>? _cachedRgbInput;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final interpreterOptions = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );

      _isInitialized = true;

      debugPrint('MagicTouch Model loaded successfully');

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      debugPrint('MagicTouch Inputs:');
      for (var t in inputTensors) {
        debugPrint('  ${t.name}: ${t.shape} ${t.type}');
      }

      debugPrint('MagicTouch Outputs:');
      for (var t in outputTensors) {
        debugPrint('  ${t.name}: ${t.shape} ${t.type}');
      }
    } catch (e) {
      debugPrint('Error loading MagicTouch model: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isEncoded => _cachedRgbInput != null;

  int get originalWidth => _originalWidth;
  int get originalHeight => _originalHeight;

  int get validMaskWidth => _maskWidth;
  int get validMaskHeight => _maskHeight;

  Future<void> encodeImage(File imageFile) async {
    if (!_isInitialized) {
      throw Exception(
        'SegmentationService not initialized. Call initialize() first.',
      );
    }

    try {
      final startTime = DateTime.now();

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      _cachedImage = img.bakeOrientation(image);
      _originalWidth = _cachedImage!.width;
      _originalHeight = _cachedImage!.height;

      debugPrint(
        'MagicTouch: Image loaded ${_originalWidth}x${_originalHeight}',
      );

      _cachedMask = null;
      _maskWidth = 0;
      _maskHeight = 0;
      _cachedRgbInput = null;

      final resized = img.copyResize(
        _cachedImage!,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      _cachedRgbInput = _prepareRgbInput(resized);

      final endTime = DateTime.now();
      debugPrint(
        'MagicTouch: Image prepared in ${endTime.difference(startTime).inMilliseconds}ms',
      );

      // Auto-segmentation removed to allow user tap selection
      // debugPrint('MagicTouch: Auto-segmenting center object...');
      // await getMaskForPoint(_originalWidth / 2.0, _originalHeight / 2.0);
    } catch (e) {
      debugPrint('Error encoding image: $e');
      rethrow;
    }
  }

  Future<SegmentationResult?> getMaskForPoint(double x, double y) async {
    if (_cachedRgbInput == null || !_isInitialized) return null;

    try {
      final startTime = DateTime.now();

      final double px = (x / _originalWidth) * _inputSize;
      final double py = (y / _originalHeight) * _inputSize;

      debugPrint('MagicTouch: Clicked at ($px, $py)');

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      final inputs = <Object>[];

      for (var tensor in inputTensors) {
        final shape = tensor.shape;

        if (shape.length == 4 &&
            shape[1] == _inputSize &&
            shape[2] == _inputSize &&
            shape[3] == 4) {
          debugPrint(
            'MagicTouch: Creating 4-channel input (RGB + Interaction)',
          );
          inputs.add(_create4ChannelInput(_cachedRgbInput!, px, py));
        } else if (shape.length == 4 &&
            shape[1] == _inputSize &&
            shape[2] == _inputSize &&
            shape[3] == 3) {
          inputs.add(_cachedRgbInput!);
        }
        // Check for point input [1, 2] or [1, N, 2]
        else if ((shape.length == 2 && shape[1] == 2) ||
            (shape.length == 3 && shape[2] == 2)) {
          inputs.add(
            shape.length == 2
                ? [
                    [px, py],
                  ]
                : [
                    [
                      [px, py],
                    ],
                  ],
          );
        } else {
          debugPrint(
            'MagicTouch: Unknown input shape $shape, using default zero input',
          );
          inputs.add(_createDefaultInput(shape));
        }
      }

      final outputs = <int, Object>{};
      for (var i = 0; i < outputTensors.length; i++) {
        outputs[i] = _createOutputBuffer(outputTensors[i].shape);
      }

      _interpreter!.runForMultipleInputs(inputs, outputs);

      final mask = _parseOutput(outputs, outputTensors[0].shape);

      if (mask != null) {
        _cachedMask = mask;
        _maskWidth = _inputSize;
        _maskHeight = _inputSize;

        final endTime = DateTime.now();
        final inferenceTime = endTime
            .difference(startTime)
            .inMilliseconds
            .toDouble();

        debugPrint('MagicTouch: Inference complete in ${inferenceTime}ms');

        return SegmentationResult(
          mask: mask,
          width: _inputSize,
          height: _inputSize,
          validWidth: _inputSize,
          validHeight: _inputSize,
          inferenceTime: inferenceTime,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error getting mask: $e');
      return null;
    }
  }

  List<List<List<List<double>>>> _prepareRgbInput(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    );
  }

  List<List<List<List<double>>>> _create4ChannelInput(
    List<List<List<List<double>>>> rgb,
    double px,
    double py,
  ) {
    const double sigma = 10.0;
    const double sigmaSq2 = 2 * sigma * sigma;

    return List.generate(
      1,
      (b) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = rgb[b][y][x];
          final r = pixel[0];
          final g = pixel[1];
          final bVal = pixel[2];

          final double distSq = (x - px) * (x - px) + (y - py) * (y - py);
          final double interaction = math.exp(-distSq / sigmaSq2);

          return [r, g, bVal, interaction];
        }),
      ),
    );
  }

  dynamic _createDefaultInput(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    if (shape.length == 1) return List.filled(shape[0], 0.0);
    if (shape.length == 2)
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    if (shape.length == 3)
      return List.generate(
        shape[0],
        (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
      );
    if (shape.length == 4)
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.generate(shape[2], (_) => List.filled(shape[3], 0.0)),
        ),
      );
    return 0.0;
  }

  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    if (shape.length == 1) return List.filled(shape[0], 0.0);
    if (shape.length == 2)
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    if (shape.length == 3)
      return List.generate(
        shape[0],
        (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
      );
    if (shape.length == 4)
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.generate(shape[2], (_) => List.filled(shape[3], 0.0)),
        ),
      );
    return List.filled(1, 0.0);
  }

  Uint8List? _parseOutput(Map<int, Object> outputs, List<int> shape) {
    try {
      final output = outputs[0];
      if (output == null) return null;

      debugPrint('MagicTouch Output Shape: $shape');

      final mask = Uint8List(_inputSize * _inputSize);
      int pixelCount = 0;

      if (shape.length == 4) {
        final out4d = output as List<List<List<List<double>>>>;

        bool channelsLast = shape[3] <= 2;
        int h = channelsLast ? shape[1] : shape[2];
        int w = channelsLast ? shape[2] : shape[3];

        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            double val;
            if (channelsLast) {
              val = out4d[0][y][x][0];
              if (shape[3] == 2) {
                val = out4d[0][y][x][1];
              }
            } else {
              val = out4d[0][0][y][x];
            }

            if (val > 0.5) {
              mask[y * w + x] = 255;
              pixelCount++;
            } else {
              mask[y * w + x] = 0;
            }
          }
        }
      }

      debugPrint('MagicTouch: Found $pixelCount pixels');
      if (pixelCount == 0) return null;
      return mask;
    } catch (e) {
      debugPrint('Error parsing output: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _cachedMask = null;
    _cachedImage = null;
    _cachedRgbInput = null;
  }

  Future<List<Uint8List>> getAllSegments() async {
    if (_cachedMask == null) return [];
    return [_cachedMask!];
  }

  Future<CutoutResult?> createCutout(File imageFile) async {
    if (_cachedMask == null) {
      debugPrint('createCutout: No cached mask available');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('createCutout: Failed to decode image');
        return null;
      }

      final oriented = img.bakeOrientation(image);
      debugPrint(
        'createCutout: Image ${oriented.width}x${oriented.height}, Mask ${_maskWidth}x${_maskHeight}',
      );

      final double scaleX = _maskWidth.toDouble() / oriented.width.toDouble();
      final double scaleY = _maskHeight.toDouble() / oriented.height.toDouble();

      debugPrint('createCutout: Scale factors X=$scaleX, Y=$scaleY');

      int minX = oriented.width;
      int minY = oriented.height;
      int maxX = 0;
      int maxY = 0;
      int pixelCount = 0;

      for (int y = 0; y < oriented.height; y++) {
        for (int x = 0; x < oriented.width; x++) {
          final int mx = (x * scaleX).round().clamp(0, _maskWidth - 1);
          final int my = (y * scaleY).round().clamp(0, _maskHeight - 1);

          final index = my * _maskWidth + mx;
          if (index >= 0 &&
              index < _cachedMask!.length &&
              _cachedMask![index] > 0) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
            pixelCount++;
          }
        }
      }

      debugPrint(
        'createCutout: Found $pixelCount pixels, Bounds: ($minX,$minY) -> ($maxX,$maxY)',
      );

      if (pixelCount == 0 || minX > maxX || minY > maxY) {
        debugPrint('createCutout: No valid mask pixels found!');
        return null;
      }

      final width = maxX - minX + 1;
      final height = maxY - minY + 1;

      debugPrint('createCutout: Creating cutout of size ${width}x${height}');

      final cutout = img.Image(width: width, height: height, numChannels: 4);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final srcX = minX + x;
          final srcY = minY + y;
          final int mx = (srcX * scaleX).round().clamp(0, _maskWidth - 1);
          final int my = (srcY * scaleY).round().clamp(0, _maskHeight - 1);

          final index = my * _maskWidth + mx;
          final isPerson =
              index >= 0 &&
              index < _cachedMask!.length &&
              _cachedMask![index] > 0;

          if (isPerson) {
            final pixel = oriented.getPixel(srcX, srcY);
            cutout.setPixel(x, y, pixel);
          } else {
            cutout.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(cutout));
      debugPrint('createCutout: Generated PNG with ${pngBytes.length} bytes');

      return CutoutResult(
        imageBytes: pngBytes,
        x: minX,
        y: minY,
        width: width,
        height: height,
      );
    } catch (e) {
      debugPrint('Error creating cutout: $e');
      return null;
    }
  }
}
