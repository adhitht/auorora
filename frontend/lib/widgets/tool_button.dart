import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/liquid_glass_theme.dart';

class ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<ToolButton> createState() => ToolButtonState();
}

class ToolButtonState extends State<ToolButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LiquidGlassTheme.animationFast,
    );

    _scale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassTheme.springCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _controller.forward();
  void _up(TapUpDetails _) => _controller.reverse();
  void _cancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapCancel: _cancel,
      onTapUp: _up,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LiquidGlassTheme.spacingLarge,
            vertical: LiquidGlassTheme.spacingSmall,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(
              LiquidGlassTheme.borderRadiusMedium,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 28, color: LiquidGlassTheme.primary),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: LiquidGlassTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
