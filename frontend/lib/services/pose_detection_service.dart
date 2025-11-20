import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ui' as ui;
import '../models/pose_landmark.dart';

class PoseDetectionService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  static const String _modelPath = 'assets/models/pose_landmark_full.tflite';
  static const int _inputSize = 192;
  static const int _numLandmarks = 17;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final interpreterOptions = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );

      _isInitialized = true;
      debugPrint('Pose detection model loaded successfully');
    } catch (e) {
      debugPrint('Error loading pose detection model: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  Future<PoseDetectionResult?> detectPose(File imageFile) async {
    if (!_isInitialized) {
      throw Exception(
        'Pose detection service not initialized. Call initialize() first.',
      );
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final inputTensor = await _preprocessImage(image);

      final output = _runInference(inputTensor);

      final result = _parseOutput(output);

      image.dispose();
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<List<List<List<List<int>>>>> _preprocessImage(ui.Image image) async {
    final resized = await _resizeImage(image, _inputSize, _inputSize);

    final byteData = await resized.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw Exception('Failed to convert image to bytes');
    }

    final pixels = byteData.buffer.asUint8List();

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixelIndex = (y * _inputSize + x) * 4;
          return [
            pixels[pixelIndex],
            pixels[pixelIndex + 1],
            pixels[pixelIndex + 2],
          ];
        }),
      ),
    );

    resized.dispose();
    return input;
  }

  Future<ui.Image> _resizeImage(ui.Image image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    final resized = await picture.toImage(width, height);
    picture.dispose();

    return resized;
  }

  List<List<List<double>>> _runInference(List<List<List<List<int>>>> input) {
    final output = List.generate(
      1,
      (_) => List.generate(
        1,
        (_) => List.generate(_numLandmarks, (_) => List.filled(3, 0.0)),
      ),
    );

    _interpreter!.run(input, output);

    return output[0];
  }

  PoseDetectionResult _parseOutput(List<List<List<double>>> output) {
    final landmarks = <PoseLandmark>[];
    double totalConfidence = 0.0;

    for (var i = 0; i < output[0].length; i++) {
      final landmarkData = output[0][i];
      final landmark = PoseLandmark(
        x: landmarkData[1],
        y: landmarkData[0],
        z: 0.0,
        visibility: landmarkData[2],
      );
      landmarks.add(landmark);
      totalConfidence += landmarkData[2];
    }

    while (landmarks.length < 33) {
      landmarks.add(PoseLandmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
    }

    final confidence = totalConfidence / output[0].length;

    return PoseDetectionResult(landmarks: landmarks, confidence: confidence);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
