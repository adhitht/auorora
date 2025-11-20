import 'package:flutter/material.dart';
import '../models/pose_landmark.dart';

class PoseVisualizationOverlay extends StatelessWidget {
  final PoseDetectionResult? poseResult;
  final Size imageSize;
  final bool showConnections;
  final Color landmarkColor;
  final Color connectionColor;

  const PoseVisualizationOverlay({
    super.key,
    required this.poseResult,
    required this.imageSize,
    this.showConnections = true,
    this.landmarkColor = Colors.greenAccent,
    this.connectionColor = Colors.blueAccent,
  });

  @override
  Widget build(BuildContext context) {
    if (poseResult == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _PosePainter(
        poseResult: poseResult!,
        imageSize: imageSize,
        showConnections: showConnections,
        landmarkColor: landmarkColor,
        connectionColor: connectionColor,
      ),
      child: Container(),
    );
  }
}

class _PosePainter extends CustomPainter {
  final PoseDetectionResult poseResult;
  final Size imageSize;
  final bool showConnections;
  final Color landmarkColor;
  final Color connectionColor;

  _PosePainter({
    required this.poseResult,
    required this.imageSize,
    required this.showConnections,
    required this.landmarkColor,
    required this.connectionColor,
  });

  static const List<List<PoseLandmarkType>> _connections = [
    [PoseLandmarkType.nose, PoseLandmarkType.leftEye],
    [PoseLandmarkType.leftEye, PoseLandmarkType.leftEar],
    [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
    [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],

    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],

    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],

    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],

    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (showConnections) {
      _drawConnections(canvas, size);
    }

    _drawLandmarks(canvas, size);
  }

  void _drawConnections(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = connectionColor.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final connection in _connections) {
      final start = poseResult.getLandmark(connection[0]);
      final end = poseResult.getLandmark(connection[1]);

      if (start != null &&
          end != null &&
          start.visibility > 0.5 &&
          end.visibility > 0.5) {
        final p1 = Offset(start.x * size.width, start.y * size.height);
        final p2 = Offset(end.x * size.width, end.y * size.height);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  void _drawLandmarks(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.fill;

    for (final landmark in poseResult.landmarks) {
      if (landmark.visibility > 0.5) {
        final position = Offset(
          landmark.x * size.width,
          landmark.y * size.height,
        );

        canvas.drawCircle(
          position,
          5.0,
          paint..color = landmarkColor.withValues(alpha: 0.3),
        );

        canvas.drawCircle(position, 3.0, paint..color = landmarkColor);
      }
    }
  }

  @override
  bool shouldRepaint(_PosePainter oldDelegate) {
    return oldDelegate.poseResult != poseResult ||
        oldDelegate.imageSize != imageSize;
  }
}
