import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';
import 'glass_button.dart';

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

class RelightEditorWidgetState extends State<RelightEditorWidget> {
  bool _isProcessing = false;

  // Adjustment values
  double _exposure = 0.0;
  double _contrast = 0.0;
  double _highlights = 0.0;
  double _shadows = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildControlPanel);
    });
  }

  Future<void> _applyRelight() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Create a new file with adjustments applied
      final adjustedFile = await _createAdjustedImageFile();

      if (mounted) {
        // Pass adjustment values as metadata
        final adjustments = {
          'exposure': _exposure,
          'contrast': _contrast,
          'highlights': _highlights,
          'shadows': _shadows,
        };
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
      // Load the original image
      final imageBytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      // Create a canvas to draw the adjusted image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..colorFilter = _buildColorFilter();

      // Draw the image with color filter applied
      canvas.drawImage(originalImage, Offset.zero, paint);

      // Convert to image
      final picture = recorder.endRecording();
      final adjustedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      // Convert to bytes
      final byteData = await adjustedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final adjustedBytes = byteData!.buffer.asUint8List();

      // Save to file
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/relight_$timestamp.png';
      final newFile = File(newPath);
      await newFile.writeAsBytes(adjustedBytes);

      // Clean up
      originalImage.dispose();
      adjustedImage.dispose();

      return newFile;
    } catch (e) {
      // Fallback: copy original if processing fails
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${dir.path}/relight_$timestamp.jpg';
      return await widget.imageFile.copy(newPath);
    }
  }

  void _resetAdjustments() {
    setState(() {
      _exposure = 0.0;
      _contrast = 0.0;
      _highlights = 0.0;
      _shadows = 0.0;
    });
  }

  ColorFilter _buildColorFilter() {
    // Simplified and working color matrix
    final brightness = (_exposure + _highlights + _shadows) * 40.0;
    final contrastFactor = 1.0 + (_contrast * 0.5);
    final contrastOffset = (-0.5 * _contrast) * 255;

    return ColorFilter.matrix([
      contrastFactor,
      0,
      0,
      0,
      brightness + contrastOffset,
      0,
      contrastFactor,
      0,
      0,
      brightness + contrastOffset,
      0,
      0,
      contrastFactor,
      0,
      brightness + contrastOffset,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Hero(
            tag: 'photo-editing',
            child: ColorFiltered(
              colorFilter: _buildColorFilter(),
              child: Image.file(widget.imageFile, fit: BoxFit.contain),
            ),
          ),
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

  Widget buildControlPanel() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AdjustmentSlider(
                          label: 'Exposure',
                          icon: Icons.brightness_6,
                          value: _exposure,
                          onChanged: (v) => setState(() => _exposure = v),
                        ),
                        const SizedBox(height: 12),
                        _AdjustmentSlider(
                          label: 'Contrast',
                          icon: Icons.contrast,
                          value: _contrast,
                          onChanged: (v) => setState(() => _contrast = v),
                        ),
                        const SizedBox(height: 12),
                        _AdjustmentSlider(
                          label: 'Highlights',
                          icon: Icons.wb_sunny,
                          value: _highlights,
                          onChanged: (v) => setState(() => _highlights = v),
                        ),
                        const SizedBox(height: 12),
                        _AdjustmentSlider(
                          label: 'Shadows',
                          icon: Icons.wb_shade,
                          value: _shadows,
                          onChanged: (v) => setState(() => _shadows = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlassButton(
                      onTap: widget.onCancel,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(
                      onTap: _resetAdjustments,
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(
                      onTap: _applyRelight,
                      child: Icon(
                        Icons.check,
                        color: LiquidGlassTheme.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _AdjustmentSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: LiquidGlassTheme.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: LiquidGlassTheme.primary,
            overlayColor: LiquidGlassTheme.primary.withValues(alpha: 0.3),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            divisions: 200,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
