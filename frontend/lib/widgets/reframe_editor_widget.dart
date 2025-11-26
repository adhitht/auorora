import 'dart:io';

import 'package:apex/widgets/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../theme/liquid_glass_theme.dart';
import '../services/segmentation_service.dart';
import '../services/pose_detection_service.dart';
import '../models/pose_landmark.dart';
import 'pose_visualization_overlay.dart';
import 'segmented_cutout_view.dart';

class ReframeEditorWidget extends StatefulWidget {
  final File imageFile;
  final VoidCallback onCancel;
  final Function(File reframedFile) onApply;
  final Function(String message, bool isSuccess)? onShowMessage;
  final Function(Widget Function() builder)? onControlPanelReady;

  const ReframeEditorWidget({
    super.key,
    required this.imageFile,
    required this.onCancel,
    required this.onApply,
    this.onShowMessage,
    this.onControlPanelReady,
  });

  @override
  State<ReframeEditorWidget> createState() => ReframeEditorWidgetState();
}

class ReframeEditorWidgetState extends State<ReframeEditorWidget> {
  bool _isProcessing = false;
  bool _isPoseDetecting = false;
  bool _isSegmentationRunning = false;
  bool _showPoseLandmarks = false;
  bool _showSegmentation = false;
  Size? _imageSize;

  PoseDetectionResult? _poseResult;
  CutoutResult? _cutoutResult;
  Offset _cutoutPosition = Offset.zero;

  final PoseDetectionService _poseService = PoseDetectionService();
  final SegmentationService _segmentationService = SegmentationService();
  bool _isPoseServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadImageSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildReframeOptionsBar);
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _poseService.initialize();
      if (mounted) {
        setState(() {
          _isPoseServiceInitialized = true;
        });
      }
    } catch (e) {
      print('Failed to initialize pose service: $e');
    }

    try {
      await _segmentationService.initialize();
      if (mounted) {
        _segmentationService.encodeImage(widget.imageFile).catchError((e) {
          print('Background encoding failed: $e');
        });
      }
    } catch (e) {
      print('Failed to initialize segmentation service: $e');
    }
  }

  Future<void> _loadImageSize() async {
    final bytes = await widget.imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image != null) {
      final oriented = img.bakeOrientation(image);
      if (mounted) {
        setState(() {
          _imageSize = Size(
            oriented.width.toDouble(),
            oriented.height.toDouble(),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _poseService.dispose();
    _segmentationService.dispose();
    super.dispose();
  }

  Future<void> _detectPose() async {
    if (_isPoseDetecting || !_isPoseServiceInitialized) return;

    setState(() {
      _isPoseDetecting = true;
    });

    try {
      final result = await _poseService.detectPose(widget.imageFile);

      if (mounted) {
        setState(() {
          _poseResult = result;
          _showPoseLandmarks = result != null;
          _isPoseDetecting = false;
        });

        if (result == null) {
          widget.onShowMessage?.call('No pose detected in image', false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPoseDetecting = false;
        });
        widget.onShowMessage?.call('Failed to detect pose: $e', false);
      }
    }
  }

  void _togglePoseVisibility() {
    setState(() {
      _showPoseLandmarks = !_showPoseLandmarks;
    });
  }

  Future<void> _handleSegmentationTrigger(double x, double y) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (!_segmentationService.isEncoded) {
        await _segmentationService.encodeImage(widget.imageFile);
      }

      final mask = await _segmentationService.getMaskForPoint(x, y);
      if (mask != null) {
        final cutout = await _segmentationService.createCutout(
          widget.imageFile,
        );

        if (mounted) {
          setState(() {
            _cutoutResult = cutout;
            _showSegmentation = true;
            _cutoutPosition = Offset.zero;
          });
        }
      } else {
        if (mounted)
          widget.onShowMessage?.call(
            'No object found at this location.',
            false,
          );
      }
    } catch (e) {
      if (mounted) widget.onShowMessage?.call('Selection failed: $e', false);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _applyReframe() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final dir = await getTemporaryDirectory();
      final newFile = File(
        '${dir.path}/reframe_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await widget.imageFile.copy(newFile.path);

      if (mounted) {
        widget.onApply(newFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        widget.onShowMessage?.call('Failed to reframe image: $e', false);
      }
    }
  }

  void _handleLandmarkMove(int index, Offset newPosition) {
    if (_poseResult == null) return;

    setState(() {
      final landmarks = List<PoseLandmark>.from(_poseResult!.landmarks);
      landmarks[index] = landmarks[index].copyWith(
        x: newPosition.dx,
        y: newPosition.dy,
      );

      _poseResult = PoseDetectionResult(
        landmarks: landmarks,
        confidence: _poseResult!.confidence,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildReframeWidget(),

        if (_isProcessing || _isSegmentationRunning || _isPoseDetecting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: LiquidGlassTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSegmentationRunning
                          ? 'Segmenting...'
                          : _isPoseDetecting
                          ? 'Detecting pose...'
                          : 'Processing...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReframeWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Hero(
        tag: 'photo-editing',
        child: LayoutBuilder(
          builder: (context, constraints) {
            double imageDisplayWidth = 0;
            double imageDisplayHeight = 0;
            double offsetX = 0;
            double offsetY = 0;

            if (_imageSize != null) {
              final double scaleX = constraints.maxWidth / _imageSize!.width;
              final double scaleY = constraints.maxHeight / _imageSize!.height;
              final double scale = scaleX < scaleY ? scaleX : scaleY;

              imageDisplayWidth = _imageSize!.width * scale;
              imageDisplayHeight = _imageSize!.height * scale;

              offsetX = (constraints.maxWidth - imageDisplayWidth) / 2;
              offsetY = (constraints.maxHeight - imageDisplayHeight) / 2;
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onLongPressStart: (details) {
                    if (_imageSize != null) {
                      final double left = offsetX;
                      final double top = offsetY;
                      final double right = left + imageDisplayWidth;
                      final double bottom = top + imageDisplayHeight;

                      final localPos = details.localPosition;

                      if (localPos.dx >= left &&
                          localPos.dx <= right &&
                          localPos.dy >= top &&
                          localPos.dy <= bottom) {
                        // Map to original image coordinates
                        final double relativeX =
                            (localPos.dx - left) / imageDisplayWidth;
                        final double relativeY =
                            (localPos.dy - top) / imageDisplayHeight;

                        final double originalX = relativeX * _imageSize!.width;
                        final double originalY = relativeY * _imageSize!.height;
                        
                        HapticFeedback.mediumImpact();
                        _handleSegmentationTrigger(originalX, originalY);
                      }
                    }
                  },
                  child: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),

                if (_showPoseLandmarks &&
                    _poseResult != null &&
                    _imageSize != null)
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: imageDisplayWidth,
                    height: imageDisplayHeight,
                    child: PoseVisualizationOverlay(
                      poseResult: _poseResult,
                      imageSize: Size(imageDisplayWidth, imageDisplayHeight),
                      showConnections: true,
                      onLandmarkMoved: _handleLandmarkMove,
                    ),
                  ),

                // Segmentation cutout
                if (_showSegmentation &&
                    _cutoutResult != null &&
                    _imageSize != null)
                  Positioned(
                    left:
                        offsetX +
                        (_cutoutResult!.x *
                            (imageDisplayWidth / _imageSize!.width)) +
                        _cutoutPosition.dx,
                    top:
                        offsetY +
                        (_cutoutResult!.y *
                            (imageDisplayHeight / _imageSize!.height)) +
                        _cutoutPosition.dy,
                    width:
                        _cutoutResult!.width *
                        (imageDisplayWidth / _imageSize!.width),
                    height:
                        _cutoutResult!.height *
                        (imageDisplayHeight / _imageSize!.height),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _cutoutPosition += details.delta;
                        });
                      },
                      child: SegmentedCutoutView(
                        imageBytes: _cutoutResult!.imageBytes,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildReframeOptionsBar() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),
      child: Row(
        children: [
          // Pose detection button
          GlassButton(
            onTap: _poseResult == null ? _detectPose : _togglePoseVisibility,
            child: Icon(
              _poseResult != null
                  ? CupertinoIcons.person_crop_circle_fill
                  : CupertinoIcons.person_crop_circle,
              color: _showPoseLandmarks
                  ? LiquidGlassTheme.primary
                  : Colors.white,
            ),
          ),

          const SizedBox(width: 12),

          // Segmentation button removed as per request
          /*
          GlassButton(
            onTap: _toggleSegmentationVisibility,
            child: Icon(
              _showSegmentation
                  ? CupertinoIcons.person_crop_rectangle_fill
                  : CupertinoIcons.person_crop_rectangle,
              color: _showSegmentation
                  ? LiquidGlassTheme.primary
                  : Colors.white,
            ),
          ),
          */
          const Spacer(),

          GlassButton(onTap: _applyReframe, child: const Icon(Icons.check)),
        ],
      ),
    );
  }
}
