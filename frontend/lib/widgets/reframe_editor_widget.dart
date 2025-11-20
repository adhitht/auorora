import 'dart:io';
import 'dart:ui' as ui;

import 'package:apex/widgets/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/pose_detection_service.dart';
import '../models/pose_landmark.dart';
import 'pose_visualization_overlay.dart';

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
  bool _showPoseLandmarks = false;
  PoseDetectionResult? _poseResult;
  Size? _imageSize;

  final PoseDetectionService _poseService = PoseDetectionService();
  bool _isPoseServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePoseService();
    _loadImageSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildReframeOptionsBar);
    });
  }

  Future<void> _initializePoseService() async {
    try {
      await _poseService.initialize();
      if (mounted) {
        setState(() {
          _isPoseServiceInitialized = true;
        });
      }
    } catch (e) {
      print('Failed to initialize pose service: $e');
      if (mounted) {
        widget.onShowMessage?.call(
          'Pose detection not available: Model file missing',
          false,
        );
      }
    }
  }

  Future<void> _loadImageSize() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    if (mounted) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }

    image.dispose();
  }

  @override
  void dispose() {
    _poseService.dispose();
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
        } else {
          // widget.onShowMessage?.call(
          //   'Pose detected with ${(result.confidence * 100).toStringAsFixed(1)}% confidence',
          //   true,
          // );
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildReframeWidget(),

        if (_isProcessing || _isPoseDetecting)
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
                      _isPoseDetecting ? 'Detecting pose...' : 'Processing...',
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
        child: Stack(
          children: [
            Image.file(widget.imageFile, fit: BoxFit.contain),

            if (_showPoseLandmarks && _poseResult != null && _imageSize != null)
              Positioned.fill(
                child: PoseVisualizationOverlay(
                  poseResult: _poseResult,
                  imageSize: _imageSize!,
                  showConnections: true,
                ),
              ),
          ],
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

          const Spacer(),

          GlassButton(onTap: _applyReframe, child: const Icon(Icons.check)),
        ],
      ),
    );
  }
}
