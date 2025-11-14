import 'package:apex/theme/liquid_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LiquidGlassLayer(
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

