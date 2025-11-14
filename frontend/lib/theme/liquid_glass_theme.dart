import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassTheme {
  // Primary colors
  static const Color primary = Color(0xFF007AFF);
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);

  // Glass effects
  static const Color glassLight = Color(0xBFFFFFFF);
  static const Color glassDark = Color(0x40000000);

  // Accents
  static const Color accent = Color(0xFF5E5CE6); 
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);

  // Blur effect configurations
  static const double lightBlurSigma = 10.0;
  static const double mediumBlurSigma = 20.0;
  static const double heavyBlurSigma = 40.0;

  // Border radius constants
  static const double borderRadiusSmall = 12.0;
  static const double borderRadiusMedium = 16.0;
  static const double borderRadiusLarge = 24.0;

  // Spacing constants
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 400);

  // Touch target sizes
  static const double minTouchTarget = 44.0;

  /// Creates a light blur ImageFilter
  static ImageFilter get lightBlur =>
      ImageFilter.blur(sigmaX: lightBlurSigma, sigmaY: lightBlurSigma);

  /// Creates a medium blur ImageFilter
  static ImageFilter get mediumBlur =>
      ImageFilter.blur(sigmaX: mediumBlurSigma, sigmaY: mediumBlurSigma);

  /// Creates a heavy blur ImageFilter
  static ImageFilter get heavyBlur =>
      ImageFilter.blur(sigmaX: heavyBlurSigma, sigmaY: heavyBlurSigma);

  /// Spring animation curve for interactive elements
  static const Curve springCurve = Curves.easeOutCubic;

  /// Ease-out curve for transitions
  static const Curve transitionCurve = Curves.easeOut;
}
