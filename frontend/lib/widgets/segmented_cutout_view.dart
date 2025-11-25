import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class SegmentedCutoutView extends StatefulWidget {
  final Uint8List imageBytes;

  const SegmentedCutoutView({super.key, required this.imageBytes});

  @override
  State<SegmentedCutoutView> createState() => _SegmentedCutoutViewState();
}

class _SegmentedCutoutViewState extends State<SegmentedCutoutView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Image.memory(
                      widget.imageBytes,
                      color: Colors.white.withOpacity(0.2),
                      colorBlendMode: BlendMode.srcIn,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),

                // 2. The Image itself
                Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  color: Colors.white.withOpacity(0.15),
                  colorBlendMode: BlendMode.srcATop,
                ),

                Positioned.fill(
                  child: LiquidGlassLayer(
                    settings: LiquidGlassSettings(
                      thickness: 5,
                      blur: 0.0,
                      glassColor: Colors.white.withOpacity(0.02),
                      lightIntensity: _shimmerAnimation.value,
                      saturation: 1.0,
                    ),
                    child: Container(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
