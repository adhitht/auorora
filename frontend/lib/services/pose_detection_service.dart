import 'dart:io';
import 'dart:math';
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

      // Calculate letterbox details
      final double targetSize = _inputSize.toDouble();
      final double scale = (targetSize / image.width) < (targetSize / image.height)
          ? (targetSize / image.width)
          : (targetSize / image.height);
      
      final double newWidth = image.width * scale;
      final double newHeight = image.height * scale;
      final double dx = (targetSize - newWidth) / 2;
      final double dy = (targetSize - newHeight) / 2;

      debugPrint('PoseDetection: Image size: ${image.width}x${image.height}');
      debugPrint('PoseDetection: Scale: $scale, Padding: $dx, $dy');

      final inputTensor = await _preprocessImage(image, dx, dy, newWidth, newHeight);

      final output = _runInference(inputTensor);

      debugPrint('PoseDetection: Raw output first landmark: ${output[0][0]}');

      final result = _parseOutput(
        output,
        dx,
        dy,
        scale,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      debugPrint('PoseDetection: Parsed first landmark: ${result.landmarks[0]}');

      image.dispose();
      return result;
    } catch (e) {
      debugPrint('Error detecting pose: $e');
      return null;
    }
  }

  Future<List<List<List<List<int>>>>> _preprocessImage(
    ui.Image image,
    double dx,
    double dy,
    double newWidth,
    double newHeight,
  ) async {
    final resized = await _resizeImage(image, dx, dy, newWidth, newHeight);

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

  Future<ui.Image> _resizeImage(
    ui.Image image,
    double dx,
    double dy,
    double newWidth,
    double newHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _inputSize.toDouble(), _inputSize.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF808080),
    );

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(dx, dy, newWidth, newHeight);

    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    final resized = await picture.toImage(_inputSize, _inputSize);
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

  PoseDetectionResult _parseOutput(
    List<List<List<double>>> output,
    double paddingX,
    double paddingY,
    double scale,
    double originalWidth,
    double originalHeight,
  ) {
    final landmarks = <PoseLandmark>[];
    double totalConfidence = 0.0;

    for (var i = 0; i < output[0].length; i++) {
      final landmarkData = output[0][i];
      
      final yNorm = landmarkData[0];
      final xNorm = landmarkData[1];
      final score = landmarkData[2];

      final point = calculateOriginalCoordinate(
        xNorm,
        yNorm,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        _inputSize,
      );

      final landmark = PoseLandmark(
        x: point.x,
        y: point.y,
        z: 0.0,
        visibility: score,
      );
      landmarks.add(landmark);
      totalConfidence += score;
    }

    while (landmarks.length < 33) {
      landmarks.add(PoseLandmark(x: 0.0, y: 0.0, z: 0.0, visibility: 0.0));
    }

    final confidence = totalConfidence / output[0].length;

    return PoseDetectionResult(landmarks: landmarks, confidence: confidence);
  }

  static Point<double> calculateOriginalCoordinate(
    double xNorm,
    double yNorm,
    double paddingX,
    double paddingY,
    double scale,
    double originalWidth,
    double originalHeight,
    int inputSize,
  ) {
    // Convert to tensor pixel coordinates
    final yTensor = yNorm * inputSize;
    final xTensor = xNorm * inputSize;

    // Remove padding
    final yScaled = yTensor - paddingY;
    final xScaled = xTensor - paddingX;

    // Scale back to original image size
    final yOriginal = yScaled / scale;
    final xOriginal = xScaled / scale;

    // Normalize to original image dimensions [0, 1]
    final xFinal = xOriginal / originalWidth;
    final yFinal = yOriginal / originalHeight;

    return Point(xFinal, yFinal);
  }


  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
