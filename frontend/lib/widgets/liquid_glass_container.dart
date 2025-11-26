import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/liquid_glass_theme.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),
      child: LiquidStretch(
        stretch: 0.2, // Subtle stretch
        interactionScale: 1.02,
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: 24),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
