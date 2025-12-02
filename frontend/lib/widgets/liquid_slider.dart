import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/liquid_glass_theme.dart';

class LiquidSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  const LiquidSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  @override
  State<LiquidSlider> createState() => _LiquidSliderState();
}

class _LiquidSliderState extends State<LiquidSlider> {
  void _updateValue(double localX, double width) {
    final double percentage = (localX / width).clamp(0.0, 1.0);
    final double newValue = widget.min + percentage * (widget.max - widget.min);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = 40.0;
        final double thumbSize = 24.0;
        final double trackHeight = 6.0;

        final double percentage = (widget.value - widget.min) / (widget.max - widget.min);
        final double thumbPosition = percentage * (width - thumbSize);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            _updateValue(details.localPosition.dx, width);
          },
          onTapDown: (details) {
            HapticFeedback.selectionClick();
            _updateValue(details.localPosition.dx, width);
          },
          child: SizedBox(
            height: height,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                LiquidGlassLayer(
                  settings: const LiquidGlassSettings(
                    thickness: 25,
                    blur: 20,
                    glassColor: LiquidGlassTheme.glassDark,
                    lightIntensity: 0.15,
                    saturation: 1,
                  ),
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: trackHeight / 2),
                    child: Container(
                      height: trackHeight,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: thumbPosition.clamp(0.0, width - thumbSize),
                  child: LiquidGlassLayer(
                    settings: const LiquidGlassSettings(
                      thickness: 20,
                      blur: 15,
                      glassColor: LiquidGlassTheme.glassDark,
                      lightIntensity: 0.3,
                      saturation: 1.2,
                    ),
                    child: LiquidGlass(
                      shape: LiquidRoundedSuperellipse(borderRadius: thumbSize / 2),
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: thumbSize * 0.4, // Hollow center effect
                            height: thumbSize * 0.4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent, // See-through
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
