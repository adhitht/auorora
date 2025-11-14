import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/liquid_glass_theme.dart';


class LiquidGlassContainer extends StatelessWidget {
  
  final Widget child;

  const LiquidGlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiquidGlassTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LiquidGlassTheme.borderRadiusLarge),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                LiquidGlassTheme.borderRadiusLarge,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.2,
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.45),
                  Colors.white.withOpacity(0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: LiquidGlassTheme.spacingSmall,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
