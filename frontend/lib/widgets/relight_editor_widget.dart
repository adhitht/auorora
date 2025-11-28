import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/segmentation_service.dart';
import 'glass_button.dart';
import 'segmentation_feedback_overlay.dart';

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
  final VoidCallback onCancel;
  final Function(File relitFile, Map<String, dynamic> adjustments) onApply;
  final Function(String message, bool isSuccess)? onShowMessage;
  final Function(Widget Function() builder)? onControlPanelReady;

  const RelightEditorWidget({
    super.key,
    required this.imageFile,
    required this.onCancel,
    required this.onApply,
    this.onShowMessage,
    this.onControlPanelReady,
  });

  @override
  State<RelightEditorWidget> createState() => RelightEditorWidgetState();
}

class RelightEditorWidgetState extends State<RelightEditorWidget> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  RelightTool? _selectedTool;
  late AnimationController _panelAnimationController;
  late Animation<double> _panelAnimation;

  // Segmentation
  final SegmentationService _segmentationService = SegmentationService();
  bool _isSegmentationActive = false;
  bool _isSegmenting = false;
  ui.Image? _maskImage;

  // Adjustment values
  final Map<RelightTool, double> _values = {
    RelightTool.exposure: 0.0,
    RelightTool.contrast: 0.0,
    RelightTool.temperature: 0.0,
  };

  @override
  void initState() {
    super.initState();
    _initializeSegmentation();
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
  }

  @override
  void dispose() {
    _panelAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSegmentation() async {
    try {
      await _segmentationService.initialize();
      await _segmentationService.encodeImage(widget.imageFile);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing segmentation: $e');
    }
  }

  Future<void> _applyRelight() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final adjustedFile = await _createAdjustedImageFile();

      if (mounted) {
        final adjustments = _values.map((key, value) => MapEntry(key.name, value));
        widget.onApply(adjustedFile, adjustments);
        widget.onShowMessage?.call('Adjustments applied', true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        widget.onShowMessage?.call('Failed to apply adjustments: $e', false);
      }
    }
  }

  Future<File> _createAdjustedImageFile() async {
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
        
        canvas.saveLayer(Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()), Paint());
        canvas.drawImage(originalImage, Offset.zero, paint);
        
        final maskPaint = Paint()..blendMode = BlendMode.dstIn;
        final srcRect = Rect.fromLTWH(0, 0, _maskImage!.width.toDouble(), _maskImage!.height.toDouble());
        final dstRect = Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble());
        canvas.drawImageRect(_maskImage!, srcRect, dstRect, maskPaint);
        
        canvas.restore();
      } else {
        final paint = Paint()..colorFilter = _buildColorFilter();
        canvas.drawImage(originalImage, Offset.zero, paint);
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

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/relight_$timestamp.png';
      final newFile = File(newPath);
      await newFile.writeAsBytes(adjustedBytes);

      originalImage.dispose();
      adjustedImage.dispose();

      return newFile;
    } catch (e) {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/relight_$timestamp.jpg';
      return await widget.imageFile.copy(newPath);
    }
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
      (R + satScale) * contrastScale, G * contrastScale, B * contrastScale, 0, totalOffset + tempR,
      R * contrastScale, (G + satScale) * contrastScale, B * contrastScale, 0, totalOffset,
      R * contrastScale, G * contrastScale, (B + satScale) * contrastScale, 0, totalOffset + tempB,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_segmentationService.originalWidth == 0 || _segmentationService.originalHeight == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = _segmentationService.originalWidth / _segmentationService.originalHeight;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) => _handleTap(details, constraints, aspectRatio),
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
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
                              (Matrix4.identity()
                                    ..scale(
                                      bounds.width / _maskImage!.width,
                                      bounds.height / _maskImage!.height,
                                    ))
                                  .storage,
                            );
                          },
                          blendMode: BlendMode.dstIn,
                          child: ColorFiltered(
                            colorFilter: _buildColorFilter(),
                            child: Image.file(widget.imageFile, fit: BoxFit.fill),
                          ),
                        )
                      else if (!_isSegmentationActive)
                        ColorFiltered(
                          colorFilter: _buildColorFilter(),
                          child: Image.file(widget.imageFile, fit: BoxFit.fill),
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

                      if (_isSegmentationActive && _maskImage == null)
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: Text(
                              'Tap an object to select',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                              ),
                            ),
                          ),
                        ),
                        
                      if (_isSegmenting)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    ],
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
                  color: LiquidGlassTheme.primary,
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

  Future<void> _handleTap(TapUpDetails details, BoxConstraints constraints, double aspectRatio) async {
    if (!_isSegmentationActive || _isSegmenting) return;

    setState(() => _isSegmenting = true);

    try {
      final fittedSizes = applyBoxFit(BoxFit.contain, Size(aspectRatio, 1), constraints.biggest);
      final destinationSize = fittedSizes.destination;
      
      final double offsetX = (constraints.maxWidth - destinationSize.width) / 2;
      final double offsetY = (constraints.maxHeight - destinationSize.height) / 2;
      
      final localPosition = details.localPosition;
      
      if (localPosition.dx < offsetX || localPosition.dx > offsetX + destinationSize.width ||
          localPosition.dy < offsetY || localPosition.dy > offsetY + destinationSize.height) {
        setState(() => _isSegmenting = false);
        return;
      }

      final double relativeX = (localPosition.dx - offsetX) / destinationSize.width * _segmentationService.originalWidth;
      final double relativeY = (localPosition.dy - offsetY) / destinationSize.height * _segmentationService.originalHeight;

      final result = await _segmentationService.getMaskForPoint(relativeX, relativeY);
      
      if (result != null) {
        final int width = result.width;
        final int height = result.height;
        final int pixelCount = width * height;
        final Uint8List rgbaBytes = Uint8List(pixelCount * 4);
        
        for (int i = 0; i < pixelCount; i++) {
          final int maskVal = result.mask[i];
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
          _isSegmentationActive = false;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error handling tap: $e');
    } finally {
      setState(() => _isSegmenting = false);
    }
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
                    if (_selectedTool == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCompactButton(
                            icon: Icons.close,
                            color: Colors.white,
                            onTap: widget.onCancel,
                          ),
                          _buildCompactButton(
                            icon: _isSegmentationActive ? Icons.person_search : Icons.person_search_outlined,
                            color: _isSegmentationActive ? LiquidGlassTheme.primary : Colors.white,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _isSegmentationActive = !_isSegmentationActive;
                                if (!_isSegmentationActive) {
                                  _maskImage = null; 
                                }
                              });
                            },
                          ),
                          _buildCompactButton(
                            icon: Icons.check,
                            color: LiquidGlassTheme.primary,
                            onTap: _applyRelight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _selectedTool == null
                        ? _buildCompactToolGrid()
                        : _buildCompactSlider(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactToolGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tool Grid
        _buildToolGrid(),
      ],
    );
  }

  Widget _buildToolGrid() {
    final tools = RelightTool.values;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tools.map((tool) => _buildCompactToolButton(tool)).toList(),
    );
  }

  Widget _buildCompactToolButton(RelightTool tool) {
    final hasValue = (_values[tool] ?? 0).abs() > 0.01;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _selectedTool = tool);
        widget.onControlPanelReady?.call(buildControlPanel);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasValue 
                    ? LiquidGlassTheme.primary.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: hasValue ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    tool.icon,
                    color: hasValue ? LiquidGlassTheme.primary : Colors.white.withValues(alpha: 0.9),
                    size: 20,
                  ),
                ),
                if (hasValue)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: LiquidGlassTheme.primary.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tool.label,
            style: TextStyle(
              color: hasValue ? LiquidGlassTheme.primary : Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSlider() {
    final tool = _selectedTool!;
    final value = _values[tool]!;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tool.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Back Button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _selectedTool = null);
                widget.onControlPanelReady?.call(buildControlPanel);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Slider Track
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center Line
                    Container(
                      width: 1.5,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 40,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: LiquidGlassTheme.primary,
                        overlayColor: LiquidGlassTheme.primary.withValues(alpha: 0.1),
                        thumbShape: const _MinimalThumbShape(),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: value,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _values[tool] = v);
                          widget.onControlPanelReady?.call(buildControlPanel);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Value Display
            Container(
              width: 48,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (value * 100).toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),

            // Apply Button
            GestureDetector(
              onTap: _applyRelight,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: LiquidGlassTheme.primary.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.check, color: LiquidGlassTheme.primary, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MinimalThumbShape extends SliderComponentShape {
  const _MinimalThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(3, 28);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    
    // Glow
    final glowPaint = Paint()
      ..color = sliderTheme.thumbColor!.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 3, height: 28),
        const Radius.circular(1.5),
      ),
      glowPaint,
    );
    
    // Thumb
    final paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 3, height: 28),
        const Radius.circular(1.5),
      ),
      paint,
    );
  }
}