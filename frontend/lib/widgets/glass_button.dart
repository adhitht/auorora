import 'package:apex/theme/liquid_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.width = 42,
    this.height = 42,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.glassColor,
  });

  final Color? backgroundColor;
  final Color? borderColor;
  final Color? glassColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LiquidGlassLayer(
        settings: LiquidGlassSettings(
          thickness: 25,
          blur: 20,
          glassColor: glassColor ?? LiquidGlassTheme.glassDark,
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
                width: width,
                height: height,
                padding: padding,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: borderColor ?? Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
