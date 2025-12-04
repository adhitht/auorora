import 'package:aurora/theme/liquid_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class LiquidColorSlider extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const LiquidColorSlider({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<LiquidColorSlider> createState() => _LiquidColorSliderState();
}

class _LiquidColorSliderState extends State<LiquidColorSlider> {
  double _thumbPosition = 0.0;

  @override
  void initState() {
    super.initState();
    final HSVColor hsv = HSVColor.fromColor(widget.color);
    _thumbPosition = hsv.hue / 360.0;
  }

  @override
  void didUpdateWidget(LiquidColorSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      final HSVColor hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _updateColor(double position) {
    setState(() {
      _thumbPosition = position.clamp(0.0, 1.0);
    });

    if (_thumbPosition < 0.1) {
      widget.onColorChanged(Colors.white);
      return;
    }

    final double huePosition = (_thumbPosition - 0.1) / 0.9;
    final double hue = huePosition * 360.0;
    final Color newColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    widget.onColorChanged(newColor);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = 40.0;
        final double thumbSize = 24.0;
        final double trackHeight = 8.0;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final double newPosition =
                (_thumbPosition * width + details.delta.dx) / width;
            _updateColor(newPosition);
          },
          onTapDown: (details) {
            HapticFeedback.selectionClick();
            final double newPosition = details.localPosition.dx / width;
            _updateColor(newPosition);
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
                    shape: LiquidRoundedSuperellipse(
                      borderRadius: trackHeight / 2,
                    ),
                    child: Container(
                      height: trackHeight,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white, // Start with white
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.pink,
                            Colors.red,
                          ],
                          stops: [
                            0.0,
                            0.1, // White ends at 10%
                            0.22,
                            0.34,
                            0.46,
                            0.58,
                            0.7,
                            0.82,
                            1.0,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: (_thumbPosition * (width - thumbSize)).clamp(
                    0.0,
                    width - thumbSize,
                  ),
                  child: LiquidGlassLayer(
                    settings: const LiquidGlassSettings(
                      thickness: 20,
                      blur: 15,
                      glassColor: LiquidGlassTheme.glassDark,
                      lightIntensity: 0.2,
                      saturation: 1.2,
                    ),
                    child: LiquidGlass(
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: thumbSize / 2,
                      ),
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: thumbSize * 0.6,
                            height: thumbSize * 0.6,
                            decoration: BoxDecoration(
                              color: widget.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                ),
                              ],
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
