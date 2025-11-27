import 'dart:math' as dart_math;
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
  State<PoseVisualizationOverlay> createState() =>
      _PoseVisualizationOverlayState();
}

class _PoseVisualizationOverlayState extends State<PoseVisualizationOverlay> {
  int? _draggingIndex;
  // Store the original landmarks to calculate baseline constraints
  List<PoseLandmark>? _originalLandmarks;

  @override
  void initState() {
    super.initState();
    _captureOriginalLandmarks();
  }

  @override
  void didUpdateWidget(PoseVisualizationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update original landmarks if it's a new detection (ID changed)
    if (widget.poseResult?.id != oldWidget.poseResult?.id) {
      _captureOriginalLandmarks();
    }
  }

  void _captureOriginalLandmarks() {
    if (widget.poseResult != null) {
      // Create a deep copy or just a list copy since PoseLandmark is immutable
      _originalLandmarks = List<PoseLandmark>.from(
        widget.poseResult!.landmarks,
      );
      debugPrint(
        'PoseVisualization: Captured original landmarks for ID: ${widget.poseResult!.id}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.poseResult == null) {
      return const SizedBox.shrink();
    }

    // Fallback if not captured
    if (_originalLandmarks == null && widget.poseResult != null) {
      _captureOriginalLandmarks();
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
            connections: PoseVisualizationOverlay._connections,
          ),
        ),

        // Landmarks (Foreground Interactive)
        ...widget.poseResult!.landmarks.asMap().entries.map((entry) {
          final index = entry.key;
          final landmark = entry.value;

          if (landmark.visibility <= 0.3) return const SizedBox.shrink();

          // Center the touch target
          final left =
              landmark.x * widget.imageSize.width - 24; // 48x48 touch area
          final top = landmark.y * widget.imageSize.height - 24;

          return Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              behavior:
                  HitTestBehavior.translucent, // Ensure touches are caught
              onPanStart: (_) {
                setState(() {
                  _draggingIndex = index;
                });
              },
              onPanUpdate: (details) {
                if (widget.onLandmarkMoved != null &&
                    _originalLandmarks != null) {
                  // Add sensitivity multiplier (1.5x) to make movement feel faster
                  final sensitivity = 1.5;
                  final deltaX =
                      (details.delta.dx * sensitivity) / widget.imageSize.width;
                  final deltaY =
                      (details.delta.dy * sensitivity) /
                      widget.imageSize.height;

                  double proposedX = landmark.x + deltaX;
                  double proposedY = landmark.y + deltaY;

                  // Robust Constraint Solver
                  // Instead of just projecting to the last constraint, we try to find a position
                  // that satisfies ALL constraints.

                  // We start with the proposed position.
                  double currentX = proposedX;
                  double currentY = proposedY;

                  // Iteratively refine the position
                  for (int i = 0; i < 5; i++) {
                    // We need to check constraints against all connected neighbors of the CURRENT point.
                    // Unlike before, we don't iterate _initialNeighborDistances directly because that now contains ALL connections.

                    final currentLandmarkType = PoseLandmarkType.values
                        .firstWhere(
                          (e) => e.landmarkIndex == index,
                          orElse: () => PoseLandmarkType.nose,
                        );

                    for (final connection
                        in PoseVisualizationOverlay._connections) {
                      PoseLandmarkType? neighborType;
                      if (connection[0] == currentLandmarkType) {
                        neighborType = connection[1];
                      } else if (connection[1] == currentLandmarkType) {
                        neighborType = connection[0];
                      }

                      if (neighborType != null) {
                        final neighborIndex = neighborType.landmarkIndex;
                        final neighbor =
                            widget.poseResult!.landmarks[neighborIndex];

                        // Calculate INITIAL distance from the ORIGINAL landmarks
                        // This ensures the constraint is always relative to the original pose
                        final originalSelf = _originalLandmarks![index];
                        final originalNeighbor =
                            _originalLandmarks![neighborIndex];

                        final odx = originalSelf.x - originalNeighbor.x;
                        final ody = originalSelf.y - originalNeighbor.y;
                        final initialSqDist = odx * odx + ody * ody;

                        final dx = currentX - neighbor.x;
                        final dy = currentY - neighbor.y;
                        final currentSqDist = dx * dx + dy * dy;

                        // 5% tolerance
                        final minSq = initialSqDist * 0.9025; // 0.95^2
                        final maxSq = initialSqDist * 1.1025; // 1.05^2

                        // Handle overlap (near zero distance)
                        if (currentSqDist < 0.00000001) {
                          double dirX = landmark.x - neighbor.x;
                          double dirY = landmark.y - neighbor.y;
                          if ((dirX * dirX + dirY * dirY) < 0.00000001) {
                            dirX = 1.0;
                            dirY = 0.0;
                          }
                          final len = dart_math.sqrt(dirX * dirX + dirY * dirY);
                          dirX /= len;
                          dirY /= len;
                          final targetDist = dart_math.sqrt(minSq);
                          currentX = neighbor.x + dirX * targetDist;
                          currentY = neighbor.y + dirY * targetDist;
                          continue;
                        }

                        if (currentSqDist < minSq || currentSqDist > maxSq) {
                          final currentDist = dart_math.sqrt(currentSqDist);
                          final initialDist = dart_math.sqrt(initialSqDist);

                          double targetDist = currentDist;
                          if (currentSqDist < minSq) {
                            targetDist = initialDist * 0.95;
                          } else if (currentSqDist > maxSq) {
                            targetDist = initialDist * 1.05;
                          }

                          final scale = targetDist / currentDist;
                          currentX = neighbor.x + dx * scale;
                          currentY = neighbor.y + dy * scale;
                        }
                      }
                    }
                  }

                  // Clamp to image bounds (0-1)
                  final clampedX = currentX.clamp(0.0, 1.0);
                  final clampedY = currentY.clamp(0.0, 1.0);

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
                    border: Border.all(color: Colors.white, width: 1),
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
  final List<List<PoseLandmarkType>> connections;

  _PoseConnectionPainter({
    required this.poseResult,
    required this.showConnections,
    required this.connectionColor,
    required this.connections,
  });

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

    for (final connection in connections) {
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
