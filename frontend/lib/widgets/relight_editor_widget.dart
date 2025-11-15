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
      // TODO: Apply image adjustments using backend API
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        widget.onApply(widget.imageFile);
        widget.onShowMessage?.call('Adjustments applied', true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
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
    // Simplified and working color matrix
    final brightness = (_exposure + _highlights + _shadows) * 40.0;
    final contrastFactor = 1.0 + (_contrast * 0.5);
    final contrastOffset = (-0.5 * _contrast) * 255;

    return ColorFilter.matrix([
      contrastFactor, 0, 0, 0, brightness + contrastOffset,
      0, contrastFactor, 0, 0, brightness + contrastOffset,
      0, 0, contrastFactor, 0, brightness + contrastOffset,
      0, 0, 0, 1, 0,
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
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(
                      onTap: _resetAdjustments,
                      child: const Icon(Icons.refresh, color: Colors.white, size: 20),
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