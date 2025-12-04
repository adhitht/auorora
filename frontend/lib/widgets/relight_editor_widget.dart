import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aurora/services/relighting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/segmentation_service.dart';
import 'glass_button.dart';
import 'segmentation_feedback_overlay.dart';
import 'light_paint_stroke.dart';
import 'light_paint_painter.dart';
import 'liquid_color_slider.dart';
import 'liquid_slider.dart';
import 'relight_editor_controller.dart';
import 'package:aurora/models/relighting_model.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum RelightMode { relight, custom }

enum RelightTool {
  exposure,
  contrast,
  temperature;

  String get label {
    switch (this) {
      case RelightTool.exposure:
        return 'Exposure';
      case RelightTool.contrast:
        return 'Contrast';
      case RelightTool.temperature:
        return 'Warmth';
    }
  }

  IconData get icon {
    switch (this) {
      case RelightTool.exposure:
        return Icons.exposure;
      case RelightTool.contrast:
        return Icons.contrast;
      case RelightTool.temperature:
        return Icons.thermostat;
    }
  }
}

class RelightEditorWidget extends StatefulWidget {
  final File imageFile;
  final SegmentationService segmentationService; // Add parameter
  final VoidCallback onCancel;
  final Function(File relitFile, Map<String, dynamic> adjustments) onApply;
  final Function(String message, bool isSuccess)? onShowMessage;
  final Function(Widget Function() builder)? onControlPanelReady;
  final RelightEditorController? controller;

  const RelightEditorWidget({
    super.key,
    required this.imageFile,
    required this.segmentationService,
    required this.onCancel,
    required this.onApply,
    this.onShowMessage,
    this.onControlPanelReady,
    this.controller,
  });

  @override
  State<RelightEditorWidget> createState() => RelightEditorWidgetState();
}

class RelightEditorWidgetState extends State<RelightEditorWidget>
    with TickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isInitializing = true; // Add initializing state

  late AnimationController _panelAnimationController;
  late Animation<double> _panelAnimation;
  late AnimationController _zoomAnimationController;

  RelightMode _currentMode = RelightMode.relight;

  // Segmentation
  // Remove local instantiation
  bool _isSegmentationActive = false;
  bool _isSegmenting = false;
  ui.Image? _maskImage;

  // Adjustment values
  final Map<RelightTool, double> _values = {
    RelightTool.exposure: 0.0,
    RelightTool.contrast: 0.0,
    RelightTool.temperature: 0.0,
  };

  bool _isLightPaintActive = true;
  bool _isLightPaintSelecting = false;
  final TransformationController _transformationController =
      TransformationController();
  List<LightPaintStroke> _lightPaintStrokes = [];
  Color _currentBrushColor = const Color(0xFFFFFFFF);
  double _currentBrushBrightness = 0.5;
  LightPaintType _lightPaintTool = LightPaintType.brush;
  Rect? _selectedObjectBounds;
  Timer? _spotGrowthTimer;
  int _pointerCount = 0;
  bool _isLightPaintMoving = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOutCubic,
    );
    _panelAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildControlPanel);
    });
    
    if (widget.controller != null) {
      widget.controller!.addListener(_onControllerChanged);
      // Initialize with controller strokes if any
      if (widget.controller!.strokes.isNotEmpty) {
        _lightPaintStrokes = List.from(widget.controller!.strokes);
      }
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _lightPaintStrokes = List.from(widget.controller!.strokes);
      });
    }
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _panelAnimationController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _initializeSegmentation() async {
    // Handled by parent
  }

  // Future<Uint8List?> _getMaskBytes() async {
  //   if (_maskImage == null) return null;

  //   final ByteData? byteData = await _maskImage!.toByteData(
  //     format: ui.ImageByteFormat.png,
  //   );

  //   return byteData?.buffer.asUint8List();
  // }

  Future<Uint8List?> _getMaskBytes() async {
    if (_maskImage == null) return null;

    final targetWidth = widget.segmentationService.originalWidth;
    final targetHeight = widget.segmentationService.originalHeight;

    if (targetWidth == 0 || targetHeight == 0) return null;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(
        0,
        0,
        _maskImage!.width.toDouble(),
        _maskImage!.height.toDouble(),
      );

      final dstRect = Rect.fromLTWH(
        0,
        0,
        targetWidth.toDouble(),
        targetHeight.toDouble(),
      );

      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(_maskImage!, srcRect, dstRect, paint);

      final picture = recorder.endRecording();
      final fullSizeMask = await picture.toImage(targetWidth, targetHeight);

      final byteData = await fullSizeMask.toByteData(
        format: ui.ImageByteFormat.png,
      );

      fullSizeMask.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error upscaling mask: $e');
      return null;
    }
  }

  Future<void> _applyRelight() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final service = RelightingService();

    final imageBytes = await widget.imageFile.readAsBytes();
    final maskBytes = await _getMaskBytes();
    final lights = _generateLightsFromStrokes();

    if (lights.isEmpty && maskBytes == null) {
      debugPrint("No lights or mask selected.");
    }

    final processedBytes = await service.sendImageForRelighting(
      imageBytes,
      lights: lights,
      maskBytes: maskBytes,
    );

    if (processedBytes == null) {
      debugPrint("Failed to process image.");
      setState(() => _isProcessing = false);
      widget.onShowMessage?.call('Failed to process image', false);
      return;
    }

    try {
      final processedFile = await _createAdjustedImageFile(processedBytes);

      if (mounted) {
        final adjustments = _values.map(
          (key, value) => MapEntry(key.name, value),
        );
        widget.onApply(processedFile, adjustments);
        widget.onShowMessage?.call('Adjustments applied', true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        widget.onShowMessage?.call('Failed to apply adjustments: $e', false);
      }
    }
  }

  Future<Uint8List> _createAdjustedImageByte() async {
    try {
      final imageBytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImage(originalImage, Offset.zero, Paint());

      if (_maskImage != null) {
        final paint = Paint()..colorFilter = _buildColorFilter();

        canvas.saveLayer(
          Rect.fromLTWH(
            0,
            0,
            originalImage.width.toDouble(),
            originalImage.height.toDouble(),
          ),
          Paint(),
        );
        canvas.drawImage(originalImage, Offset.zero, paint);

        final maskPaint = Paint()..blendMode = BlendMode.dstIn;
        final srcRect = Rect.fromLTWH(
          0,
          0,
          _maskImage!.width.toDouble(),
          _maskImage!.height.toDouble(),
        );
        final dstRect = Rect.fromLTWH(
          0,
          0,
          originalImage.width.toDouble(),
          originalImage.height.toDouble(),
        );
        canvas.drawImageRect(_maskImage!, srcRect, dstRect, maskPaint);

        canvas.restore();
      } else {
        final paint = Paint()..colorFilter = _buildColorFilter();
        canvas.drawImage(originalImage, Offset.zero, paint);
      }

      // Draw Light Paint Strokes
      if (_lightPaintStrokes.isNotEmpty) {
        for (final stroke in _lightPaintStrokes) {
          if (stroke.points.isEmpty) continue;

          if (stroke.type == LightPaintType.spot) {
            // Draw Spot
            final center = Offset(
              stroke.points.first.dx * originalImage.width,
              stroke.points.first.dy * originalImage.height,
            );

            // Outer glow
            final glowPaint = Paint()
              ..color = stroke.color.withOpacity(stroke.brightness * 0.6)
              ..style = PaintingStyle.fill
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

            canvas.drawCircle(
              center,
              stroke.width * (originalImage.width / 1000.0) * 1.5,
              glowPaint,
            );

            // Core
            final corePaint = Paint()
              ..color = Colors.white.withOpacity(0.9)
              ..style = PaintingStyle.fill
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

            canvas.drawCircle(
              center,
              stroke.width * (originalImage.width / 1000.0) * 0.5,
              corePaint,
            );
          } else {
            // Draw Brush Stroke
            final paint = Paint()
              ..color = stroke.color.withOpacity(stroke.brightness)
              ..strokeWidth =
                  stroke.width *
                  (originalImage.width /
                      1000.0) // Scale width relative to image size
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(
                BlurStyle.normal,
                10,
              ); // Glow effect

            final path = Path();
            final firstPoint = Offset(
              stroke.points.first.dx * originalImage.width,
              stroke.points.first.dy * originalImage.height,
            );
            path.moveTo(firstPoint.dx, firstPoint.dy);

            for (int i = 1; i < stroke.points.length; i++) {
              final point = Offset(
                stroke.points[i].dx * originalImage.width,
                stroke.points[i].dy * originalImage.height,
              );
              path.lineTo(point.dx, point.dy);
            }
            canvas.drawPath(path, paint);

            // Draw core
            final corePaint = Paint()
              ..color = Colors.white.withOpacity(stroke.brightness * 0.8)
              ..strokeWidth =
                  (stroke.width * 0.4) * (originalImage.width / 1000.0)
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke;

            canvas.drawPath(path, corePaint);
          }
        }
      }

      final picture = recorder.endRecording();
      final adjustedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      final byteData = await adjustedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final adjustedBytes = byteData!.buffer.asUint8List();

      originalImage.dispose();
      adjustedImage.dispose();

      return adjustedBytes;
    } catch (e) {
      final imageBytes = await widget.imageFile.readAsBytes();
      return imageBytes;
    }
  }

  Future<File> _createAdjustedImageFile(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${dir.path}/relight_$timestamp.png';
    final newFile = File(newPath);
    await newFile.writeAsBytes(imageBytes);

    return newFile;
  }

  List<Light> _generateLightsFromStrokes() {
    return _lightPaintStrokes.map((stroke) {
      final colorHex =
          '#${stroke.color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

      final temperature = (stroke.brightness * 10000).toInt().clamp(
        1000,
        10000,
      );

      if (stroke.type == LightPaintType.spot) {
        final centerPoint = stroke.points.last;

        return Light(
          geometry: LightGeometry(
            type: 'SingleLightSource',
            center: [centerPoint.dx, centerPoint.dy],
            radius: stroke.width / 1000.0,
          ),
          properties: LightProperties(
            temperature: temperature,
            color: colorHex,
          ),
        );
      } else {
        return Light(
          geometry: LightGeometry(
            type: 'LineString',
            coordinates: stroke.points.map((p) => [p.dx, p.dy]).toList(),
          ),
          properties: LightProperties(
            temperature: temperature,
            color: colorHex,
          ),
        );
      }
    }).toList();
  }

  void _resetAdjustments() {
    setState(() {
      for (var key in _values.keys) {
        _values[key] = 0.0;
      }
      _maskImage = null;
    });
    widget.onControlPanelReady?.call(buildControlPanel);
  }

  ColorFilter _buildColorFilter() {
    final exposure = _values[RelightTool.exposure]!;
    final contrast = _values[RelightTool.contrast]!;
    final temperature = _values[RelightTool.temperature]!;

    final brightnessOffset = exposure * 100.0;
    final contrastScale = 1.0 + contrast;
    final contrastOffset = 128.0 * (1.0 - contrastScale);
    final satScale = 1.0;

    const double rLum = 0.2126;
    const double gLum = 0.7152;
    const double bLum = 0.0722;

    final invSat = 1.0 - satScale;
    final R = invSat * rLum;
    final G = invSat * gLum;
    final B = invSat * bLum;

    final tempR = temperature > 0 ? temperature * 40.0 : 0.0;
    final tempB = temperature < 0 ? -temperature * 40.0 : 0.0;

    final totalOffset = contrastOffset + brightnessOffset;

    return ColorFilter.matrix([
      (R + satScale) * contrastScale,
      G * contrastScale,
      B * contrastScale,
      0,
      totalOffset + tempR,
      R * contrastScale,
      (G + satScale) * contrastScale,
      B * contrastScale,
      0,
      totalOffset,
      R * contrastScale,
      G * contrastScale,
      (B + satScale) * contrastScale,
      0,
      totalOffset + tempB,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing ||
        widget.segmentationService.originalWidth == 0 ||
        widget.segmentationService.originalHeight == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio =
        widget.segmentationService.originalWidth /
        widget.segmentationService.originalHeight;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                if (!_isLightPaintMoving) {
                  _handleTap(details, constraints, aspectRatio);
                }
              },
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: _isLightPaintMoving,
                    scaleEnabled: _isLightPaintMoving,
                    boundaryMargin: const EdgeInsets.all(1000.0),
                    minScale: 0.7,
                    maxScale: 5.0,
                    onInteractionStart: (details) {
                      if (_isLightPaintActive &&
                          !_isLightPaintMoving &&
                          details.pointerCount > 1) {
                        _cancelCurrentStroke();
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'photo-editing',
                          child: Image.file(widget.imageFile, fit: BoxFit.fill),
                        ),

                        if (_maskImage != null)
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return ImageShader(
                                _maskImage!,
                                TileMode.clamp,
                                TileMode.clamp,
                                (Matrix4.identity()..scale(
                                      bounds.width / _maskImage!.width,
                                      bounds.height / _maskImage!.height,
                                    ))
                                    .storage,
                              );
                            },
                            blendMode: BlendMode.dstIn,
                            child: ColorFiltered(
                              colorFilter: _buildColorFilter(),
                              child: Image.file(
                                widget.imageFile,
                                fit: BoxFit.fill,
                              ),
                            ),
                          )
                        else if (!_isSegmentationActive)
                          ColorFiltered(
                            colorFilter: _buildColorFilter(),
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.fill,
                            ),
                          ),

                        if (_maskImage != null)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return SegmentationFeedbackOverlay(
                                key: ValueKey(_maskImage.hashCode),
                                maskImage: _maskImage!,
                                imageSize: constraints.biggest,
                              );
                            },
                          ),

                        if ((_isSegmentationActive || _isLightPaintSelecting) &&
                            _maskImage == null)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: Text(
                                'Tap an object to select',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (_isLightPaintActive) ...[
                          // Greyish canvas overlay
                          Container(color: Colors.black.withValues(alpha: 0.2)),
                          // Drawing layer
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: LightPaintPainter(
                                strokes: _lightPaintStrokes,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return IgnorePointer(
                                    ignoring: _isLightPaintMoving,
                                    child: Listener(
                                      onPointerDown: (_) => _pointerCount++,
                                      onPointerUp: (_) => _pointerCount--,
                                      onPointerCancel: (_) => _pointerCount--,
                                      child: GestureDetector(
                                        onPanDown: (details) {
                                          if (_pointerCount > 1) return;

                                          if (_lightPaintTool ==
                                              LightPaintType.spot) {
                                            final RenderBox box =
                                                context.findRenderObject()
                                                    as RenderBox;
                                            final size = box.size;
                                            final local = details.localPosition;
                                            final normalized = Offset(
                                              local.dx / size.width,
                                              local.dy / size.height,
                                            );

                                            setState(() {
                                              _lightPaintStrokes.add(
                                                LightPaintStroke(
                                                  points: [normalized],
                                                  color: _currentBrushColor,
                                                  brightness:
                                                      _currentBrushBrightness,
                                                  width: 30.0, // Initial width
                                                  type: LightPaintType.spot,
                                                ),
                                              );
                                            });
                                            HapticFeedback.mediumImpact();
                                            _startSpotGrowth();
                                          }
                                        },
                                        onPanStart: (details) {
                                          if (_pointerCount > 1) return;

                                          if (_lightPaintTool ==
                                              LightPaintType.brush) {
                                            final RenderBox box =
                                                context.findRenderObject()
                                                    as RenderBox;
                                            final size = box.size;
                                            final local = details.localPosition;
                                            final normalized = Offset(
                                              local.dx / size.width,
                                              local.dy / size.height,
                                            );

                                            setState(() {
                                              _lightPaintStrokes.add(
                                                LightPaintStroke(
                                                  points: [normalized],
                                                  color: _currentBrushColor,
                                                  brightness:
                                                      _currentBrushBrightness,
                                                  width: 20.0,
                                                  type: LightPaintType.brush,
                                                ),
                                              );
                                            });
                                          }
                                        },
                                        onPanUpdate: (details) {
                                          if (_pointerCount > 1) return;

                                          final RenderBox box =
                                              context.findRenderObject()
                                                  as RenderBox;
                                          final size = box.size;
                                          final local = details.localPosition;
                                          final normalized = Offset(
                                            local.dx / size.width,
                                            local.dy / size.height,
                                          );

                                          if (_lightPaintTool ==
                                              LightPaintType.brush) {
                                            setState(() {
                                              final currentStroke =
                                                  _lightPaintStrokes.last;
                                              currentStroke.points.add(
                                                normalized,
                                              );
                                            });
                                          } else if (_lightPaintTool ==
                                              LightPaintType.spot) {
                                            // Reset growth timer to prevent growth while moving
                                            _startSpotGrowth();

                                            // Move the spot
                                            setState(() {
                                              final lastStroke =
                                                  _lightPaintStrokes.last;
                                              _lightPaintStrokes[_lightPaintStrokes
                                                      .length -
                                                  1] = LightPaintStroke(
                                                points: [
                                                  normalized,
                                                ], // Update position
                                                color: lastStroke.color,
                                                brightness:
                                                    lastStroke.brightness,
                                                width: lastStroke
                                                    .width, // Keep growing width
                                                type: LightPaintType.spot,
                                              );
                                            });
                                            widget.controller?.updateStrokes(_lightPaintStrokes);
                                          }
                                        },
                                        onPanEnd: (details) =>
                                            _stopSpotGrowth(),
                                        onPanCancel: () {
                                          _stopSpotGrowth();
                                          // Remove the last stroke if it was cancelled (e.g. by zoom)
                                          if (_lightPaintStrokes.isNotEmpty) {
                                            setState(() {
                                              _lightPaintStrokes.removeLast();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        if (_isSegmenting)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(
                  color: LiquidGlassTheme.bottomBarPrimaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassButton(
      onTap: onTap,
      child: Icon(icon, color: color, size: 22),
    );
  }

  Future<void> _handleTap(
    TapUpDetails details,
    BoxConstraints constraints,
    double aspectRatio,
  ) async {
    // Allow tap if in segmentation mode OR if in Light Paint selection mode
    if ((!_isSegmentationActive && !_isLightPaintSelecting) || _isSegmenting)
      return;

    setState(() => _isSegmenting = true);

    try {
      final fittedSizes = applyBoxFit(
        BoxFit.contain,
        Size(aspectRatio, 1),
        constraints.biggest,
      );
      final destinationSize = fittedSizes.destination;

      final double offsetX = (constraints.maxWidth - destinationSize.width) / 2;
      final double offsetY =
          (constraints.maxHeight - destinationSize.height) / 2;

      final localPosition = details.localPosition;

      if (localPosition.dx < offsetX ||
          localPosition.dx > offsetX + destinationSize.width ||
          localPosition.dy < offsetY ||
          localPosition.dy > offsetY + destinationSize.height) {
        setState(() => _isSegmenting = false);
        return;
      }

      final double relativeX =
          (localPosition.dx - offsetX) /
          destinationSize.width *
          widget.segmentationService.originalWidth;
      final double relativeY =
          (localPosition.dy - offsetY) /
          destinationSize.height *
          widget.segmentationService.originalHeight;

      final result = await widget.segmentationService.getMaskForPoint(
        relativeX,
        relativeY,
      );

      if (result != null) {
        final int width = result.width;
        final int height = result.height;
        final int pixelCount = width * height;
        final Uint8List rgbaBytes = Uint8List(pixelCount * 4);

        // Calculate bounds for zoom
        int minX = width;
        int maxX = 0;
        int minY = height;
        int maxY = 0;

        for (int i = 0; i < pixelCount; i++) {
          final int maskVal = result.mask[i];
          if (maskVal > 0) {
            int x = i % width;
            int y = i ~/ width;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }

          rgbaBytes[i * 4 + 0] = 255;
          rgbaBytes[i * 4 + 1] = 255;
          rgbaBytes[i * 4 + 2] = 255;
          rgbaBytes[i * 4 + 3] = maskVal;
        }

        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromPixels(
          rgbaBytes,
          width,
          height,
          ui.PixelFormat.rgba8888,
          (ui.Image img) => completer.complete(img),
        );

        final maskImage = await completer.future;

        setState(() {
          _maskImage = maskImage;
          if (_isLightPaintSelecting) {
            final double scaleX =
                widget.segmentationService.originalWidth / width;
            final double scaleY =
                widget.segmentationService.originalHeight / height;

            _selectedObjectBounds = Rect.fromLTRB(
              minX * scaleX,
              minY * scaleY,
              maxX * scaleX,
              maxY * scaleY,
            );

            // Use destinationSize (image display size) for viewSize, and 0 offsets because InteractiveViewer's content is the image
            _zoomToObject(destinationSize, destinationSize, 0, 0);
            _isLightPaintActive = true;
            _isLightPaintSelecting = false;
            // Initialize with empty strokes
            _lightPaintStrokes = [];
          } else {
            _isSegmentationActive = false;
          }
        });
        HapticFeedback.heavyImpact();

        if (_isLightPaintActive) {
          widget.onControlPanelReady?.call(buildControlPanel);
        }
      }
    } catch (e) {
      debugPrint('Error handling tap: $e');
    } finally {
      setState(() => _isSegmenting = false);
    }
  }

  void _zoomToObject(
    Size viewSize,
    Size imageSize,
    double offsetX,
    double offsetY,
  ) {
    if (_selectedObjectBounds == null) return;

    // Convert mask bounds to view coordinates
    final double scaleX =
        imageSize.width / widget.segmentationService.originalWidth;
    final double scaleY =
        imageSize.height / widget.segmentationService.originalHeight;

    final double viewMinX = offsetX + _selectedObjectBounds!.left * scaleX;
    final double viewMinY = offsetY + _selectedObjectBounds!.top * scaleY;
    final double viewWidth = _selectedObjectBounds!.width * scaleX;
    final double viewHeight = _selectedObjectBounds!.height * scaleY;

    // Add padding
    final double padding = 40.0;
    final double targetWidth = viewWidth + padding * 2;
    final double targetHeight = viewHeight + padding * 2;

    // Calculate zoom scale
    final double scaleW = viewSize.width / targetWidth;
    final double scaleH = viewSize.height / targetHeight;
    final double zoomScale = math.min(scaleW, scaleH).clamp(1.0, 4.0);

    // Calculate center
    final double centerX = viewMinX + viewWidth / 2;
    final double centerY = viewMinY + viewHeight / 2;

    // Calculate translation to center the object
    final double transX = viewSize.width / 2 - centerX * zoomScale;
    final double transY = viewSize.height / 2 - centerY * zoomScale;

    final Matrix4 matrix = Matrix4.identity()
      ..translate(transX, transY)
      ..scale(zoomScale);

    final animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: matrix,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });

    _zoomAnimationController.forward(from: 0.0);
  }

  void _resetZoom() {
    final animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });

    _zoomAnimationController.forward(from: 0.0);
  }

  void _startSpotGrowth() {
    _spotGrowthTimer?.cancel();
    _spotGrowthTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (_lightPaintStrokes.isEmpty) return;

      setState(() {
        final lastStroke = _lightPaintStrokes.last;
        if (lastStroke.type == LightPaintType.spot) {
          // Increase width
          final newWidth = lastStroke.width + 1.0;
          // Cap max width if needed, e.g., 200.0
          if (newWidth < 200.0) {
            _lightPaintStrokes[_lightPaintStrokes.length -
                1] = LightPaintStroke(
              points: lastStroke.points,
              color: lastStroke.color,
              brightness: lastStroke.brightness,
              width: newWidth,
              type: LightPaintType.spot,
            );
          }
        }
      });
    });
  }

  void _stopSpotGrowth() {
    _spotGrowthTimer?.cancel();
    _spotGrowthTimer = null;
  }

  Widget buildControlPanel() {
    return FadeTransition(
      opacity: _panelAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_panelAnimation),
        child: LiquidGlassLayer(
          settings: const LiquidGlassSettings(
            thickness: 20,
            blur: 25,
            glassColor: LiquidGlassTheme.glassDark,
            lightIntensity: 0.12,
            saturation: 1.1,
          ),
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentMode == RelightMode.relight
                          ? _buildLightPaintControls()
                          : _buildAdjustmentControls(),
                    ),

                    const SizedBox(height: 16),

                    _buildBottomBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Select Object Button
        _buildSvgIconButton(
          assetPath: 'assets/icons/select_object.svg',
          isActive: _isSegmentationActive || _isLightPaintSelecting,
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _isSegmentationActive = !_isSegmentationActive;
              _isLightPaintSelecting = false;
              if (!_isSegmentationActive) {
                // _maskImage = null;
              }
            });
          },
        ),

        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(
                assetPath: 'assets/icons/paint_light.svg',
                mode: RelightMode.relight,
              ),
              const SizedBox(width: 4),
              _buildModeButton(
                assetPath: 'assets/icons/custom.svg',
                mode: RelightMode.custom,
              ),
            ],
          ),
        ),

        _buildSvgIconButton(
          assetPath: 'assets/icons/tick.svg',
          isActive: false,
          onTap: _applyRelight,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required String assetPath,
    required RelightMode mode,
  }) {
    final isSelected = _currentMode == mode;
    return GlassButton(
      onTap: () {
        if (_currentMode != mode) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentMode = mode;
            _isLightPaintActive = mode == RelightMode.relight;
          });
          widget.onControlPanelReady?.call(buildControlPanel);
        }
      },
      width: 36,
      height: 36,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      glassColor: Colors.transparent,
      child: SvgPicture.asset(
        assetPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          isSelected
              ? LiquidGlassTheme.primary
              : Colors.white.withValues(alpha: 0.5),
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildSvgIconButton({
    required String assetPath,
    required VoidCallback onTap,
    bool isActive = false,
    bool isPrimary = false,
  }) {
    return GlassButton(
      onTap: onTap,
      width: 44,
      height: 44,
      backgroundColor: isPrimary
          ? Colors.white.withValues(alpha: 0.1)
          : (isActive
                ? LiquidGlassTheme.bottomBarPrimaryColor.withValues(alpha: 0.2)
                : Colors.transparent),
      borderColor: isPrimary
          ? Colors.white.withValues(alpha: 0.2)
          : (isActive
                ? LiquidGlassTheme.bottomBarPrimaryColor
                : Colors.white.withValues(alpha: 0.2)),
      child: SvgPicture.asset(
        assetPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          isActive
              ? LiquidGlassTheme.primary
              : Colors.white.withValues(alpha: 0.6),
          BlendMode.srcIn,
        ),
      ),
    );
  }

  void _cancelCurrentStroke() {
    _stopSpotGrowth();
    if (_lightPaintStrokes.isNotEmpty) {
      setState(() {
        _lightPaintStrokes.removeLast();
      });
    }
  }

  Widget _buildLightPaintControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolsGroup(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: LiquidColorSlider(
            color: _currentBrushColor,
            onColorChanged: (color) {
              setState(() => _currentBrushColor = color);
              widget.onControlPanelReady?.call(buildControlPanel);
            },
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.brightness_low, color: Colors.white70, size: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: LiquidSlider(
                  value: _currentBrushBrightness,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) {
                    setState(() => _currentBrushBrightness = v);
                    widget.onControlPanelReady?.call(buildControlPanel);
                  },
                ),
              ),
            ),
            const Icon(Icons.brightness_high, color: Colors.white70, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildToolsGroup() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 20,
        blur: 15,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.1,
        saturation: 1.0,
      ),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spot Light Tool
              _buildGroupToolButton(
                assetPath: 'assets/icons/bulb.svg',
                isActive:
                    !_isLightPaintMoving &&
                    _lightPaintTool == LightPaintType.spot,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isLightPaintMoving = false;
                    _lightPaintTool = LightPaintType.spot;
                  });
                  widget.onControlPanelReady?.call(buildControlPanel);
                },
              ),
              const SizedBox(width: 12),

              // Brush Tool
              _buildGroupToolButton(
                assetPath: 'assets/icons/pencil.svg',
                isActive:
                    !_isLightPaintMoving &&
                    _lightPaintTool == LightPaintType.brush,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isLightPaintMoving = false;
                    _lightPaintTool = LightPaintType.brush;
                  });
                  widget.onControlPanelReady?.call(buildControlPanel);
                },
              ),
              const SizedBox(width: 12),

              // Pan Tool
              _buildGroupToolButton(
                assetPath: 'assets/icons/hand.svg',
                isActive: _isLightPaintMoving,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isLightPaintMoving = true;
                  });
                  widget.onControlPanelReady?.call(buildControlPanel);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupToolButton({
    required String assetPath,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          assetPath,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isActive
                ? LiquidGlassTheme.primary
                : Colors.white.withValues(alpha: 0.4),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAdjustmentSliderRow(RelightTool.exposure),
        const SizedBox(height: 16),
        _buildAdjustmentSliderRow(RelightTool.contrast),
        const SizedBox(height: 16),
        _buildAdjustmentSliderRow(RelightTool.temperature),
      ],
    );
  }

  Widget _buildAdjustmentSliderRow(RelightTool tool) {
    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            tool.icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        // Slider
        Expanded(
          child: LiquidSlider(
            value: _values[tool] ?? 0.0,
            min: -1.0,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _values[tool] = value;
              });
              widget.onControlPanelReady?.call(buildControlPanel);
            },
          ),
        ),
      ],
    );
  }
}
