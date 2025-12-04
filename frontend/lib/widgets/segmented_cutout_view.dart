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

  late AnimationController _flowController;
  late Animation<double> _flowAnimation;

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

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Much faster
    );

    _flowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flowController, curve: Curves.easeOutQuart),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _flowController.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shimmerAnimation, _flowAnimation]),
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                  child: Image.memory(
                    widget.imageBytes,
                    color: Colors.white.withOpacity(1.0),
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Image.memory(
                    widget.imageBytes,
                    color: Colors.black.withOpacity(0.5),
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.fill,
                  ),
                ),
              ),

              Image.memory(
                widget.imageBytes,
                fit: BoxFit.fill,
                color: Colors.white.withOpacity(0.15),
                colorBlendMode: BlendMode.srcATop,
              ),

              if (!_flowController.isCompleted)
                Positioned.fill(
                  child: Opacity(
                    opacity: (1.0 - (2 * _flowAnimation.value - 1.0).abs())
                        .clamp(0.0, 1.0),
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment(
                            -2.5 + (_flowAnimation.value * 5.0),
                            -0.5,
                          ),
                          end: Alignment(
                            -1.5 + (_flowAnimation.value * 5.0),
                            0.5,
                          ),
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
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
    );
  }
}
