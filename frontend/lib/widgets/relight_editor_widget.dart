import 'dart:io';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../theme/liquid_glass_theme.dart';
import 'glass_button.dart';

class RelightEditorWidget extends StatefulWidget {
  final File imageFile;
  final VoidCallback onCancel;
  final Function(File relitFile) onApply;
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

  // Adjustment values (range: -1.0 to 1.0 for easier calculations)
  double _exposure = 0.0;
  double _contrast = 0.0;
  double _highlights = 0.0;
  double _shadows = 0.0;

  @override
  void initState() {
    super.initState();
    // Notify parent that control panel is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildControlPanel);
    });
  }

  Future<void> _applyRelight() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // TODO: Apply image adjustments using backend API
      // For now, just return the original file
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        widget.onApply(widget.imageFile);
        widget.onShowMessage?.call('Adjustments applied', true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        widget.onShowMessage?.call('Failed to apply adjustments: $e', false);
      }
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
    // Combine adjustments into a color matrix
    // Base identity matrix
    final brightness = _exposure * 0.3; // Scale exposure
    final contrastFactor = 1.0 + (_contrast * 0.5); // Scale contrast
    final highlightAdjust = _highlights * 0.2;
    final shadowAdjust = _shadows * 0.2;

    // Simple color matrix transformation
    // This is a simplified version - for production, use proper image processing
    final matrix = <double>[
      contrastFactor,
      0,
      0,
      0,
      brightness + highlightAdjust + shadowAdjust,
      0,
      contrastFactor,
      0,
      0,
      brightness + highlightAdjust + shadowAdjust,
      0,
      0,
      contrastFactor,
      0,
      brightness + highlightAdjust + shadowAdjust,
      0,
      0,
      0,
      1,
      0,
    ];

    return ColorFilter.matrix(matrix);
  }

  @override
  Widget build(BuildContext context) {
    return _buildImagePreview();
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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

  // This method returns the control panel widget that should be positioned
  // at the bottom of the screen by the parent
  Widget buildControlPanel() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),
      child: LiquidStretch(
        stretch: 0.5,
        interactionScale: 1.05,
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: 50),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrollable adjustment sliders
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAdjustmentSlider(
                            'Exposure',
                            Icons.brightness_6,
                            _exposure,
                            (value) => setState(() => _exposure = value),
                          ),
                          const SizedBox(height: 8),
                          _buildAdjustmentSlider(
                            'Contrast',
                            Icons.contrast,
                            _contrast,
                            (value) => setState(() => _contrast = value),
                          ),
                          const SizedBox(height: 8),
                          _buildAdjustmentSlider(
                            'Highlights',
                            Icons.wb_sunny,
                            _highlights,
                            (value) => setState(() => _highlights = value),
                          ),
                          const SizedBox(height: 8),
                          _buildAdjustmentSlider(
                            'Shadows',
                            Icons.wb_shade,
                            _shadows,
                            (value) => setState(() => _shadows = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
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
      ),
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
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
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: LiquidGlassTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: LiquidGlassTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                (value * 100).toStringAsFixed(0),
                style: TextStyle(
                  color: LiquidGlassTheme.primary.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: LiquidGlassTheme.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: LiquidGlassTheme.primary,
            overlayColor: LiquidGlassTheme.primary.withValues(alpha: 0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
