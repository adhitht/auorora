import 'package:flutter/material.dart';
import '../models/pose_landmark.dart';
import 'liquid_glass_container.dart';

class PoseVisualizationOverlay extends StatefulWidget {
  final PoseDetectionResult? poseResult;
  final Size imageSize;
  final bool showConnections;
  final Color landmarkColor;
  final Color connectionColor;
  final Function(int index, Offset newPosition)? onLandmarkMoved;

  const PoseVisualizationOverlay({
    super.key,
    required this.poseResult,
    required this.imageSize,
    this.showConnections = true,
    this.landmarkColor = Colors.blue,
    this.connectionColor = Colors.white,
    this.onLandmarkMoved,
  });

  @override
  State<PoseVisualizationOverlay> createState() => _PoseVisualizationOverlayState();
}

class _PoseVisualizationOverlayState extends State<PoseVisualizationOverlay> {
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.poseResult == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Connections (Background)
        CustomPaint(
          size: widget.imageSize,
          painter: _PoseConnectionPainter(
            poseResult: widget.poseResult!,
            showConnections: widget.showConnections,
            connectionColor: widget.connectionColor,
          ),
        ),

        // Landmarks (Foreground Interactive)
        ...widget.poseResult!.landmarks.asMap().entries.map((entry) {
          final index = entry.key;
          final landmark = entry.value;

          if (landmark.visibility <= 0.3) return const SizedBox.shrink();

          // Center the touch target
          final left = landmark.x * widget.imageSize.width - 24; // 48x48 touch area
          final top = landmark.y * widget.imageSize.height - 24;

          return Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, // Ensure touches are caught
              onPanStart: (_) {
                setState(() {
                  _draggingIndex = index;
                });
              },
              onPanUpdate: (details) {
                if (widget.onLandmarkMoved != null) {
                  // Add sensitivity multiplier (1.5x) to make movement feel faster
                  final sensitivity = 1.5;
                  final newX = (left + 24 + (details.delta.dx * sensitivity)) / widget.imageSize.width;
                  final newY = (top + 24 + (details.delta.dy * sensitivity)) / widget.imageSize.height;
                  
                  // Clamp to 0-1
                  final clampedX = newX.clamp(0.0, 1.0);
                  final clampedY = newY.clamp(0.0, 1.0);

                  widget.onLandmarkMoved!(index, Offset(clampedX, clampedY));
                }
              },
              onPanEnd: (_) {
                setState(() {
                  _draggingIndex = null;
                });
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _draggingIndex == index ? 24 : 14,
                  height: _draggingIndex == index ? 24 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.landmarkColor,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                    boxShadow: [
                      // Drop shadow for depth
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      // Glow/Halo when dragging
                      if (_draggingIndex == index)
                        BoxShadow(
                          color: widget.landmarkColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // Landmark Name Label (Bottom Right - lifted to avoid bottom bar)
        if (_draggingIndex != null)
          Positioned(
            bottom: 60,
            right: 20,
            child: LiquidGlassContainer(
              child: Text(
                _getLandmarkName(_draggingIndex!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getLandmarkName(int index) {
    // Find the PoseLandmarkType that corresponds to this index
    try {
      final type = PoseLandmarkType.values.firstWhere(
        (e) => e.landmarkIndex == index,
      );
      return type.displayName;
    } catch (_) {
      return 'Point $index';
    }
  }
}

class _PoseConnectionPainter extends CustomPainter {
  final PoseDetectionResult poseResult;
  final bool showConnections;
  final Color connectionColor;

  _PoseConnectionPainter({
    required this.poseResult,
    required this.showConnections,
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
  }

  void _drawConnections(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = connectionColor.withOpacity(1)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final connection in _connections) {
      final start = poseResult.getLandmark(connection[0]);
      final end = poseResult.getLandmark(connection[1]);

      if (start != null &&
          end != null &&
          start.visibility > 0.3 &&
          end.visibility > 0.3) {
        final p1 = Offset(start.x * size.width, start.y * size.height);
        final p2 = Offset(end.x * size.width, end.y * size.height);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PoseConnectionPainter oldDelegate) {
    return oldDelegate.poseResult != poseResult;
  }
}
