import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SegmentationFeedbackOverlay extends StatefulWidget {
  final ui.Image maskImage;
  final Size imageSize;

  const SegmentationFeedbackOverlay({
    super.key,
    required this.maskImage,
    required this.imageSize,
  });

  @override
  State<SegmentationFeedbackOverlay> createState() => _SegmentationFeedbackOverlayState();
}

class _SegmentationFeedbackOverlayState extends State<SegmentationFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      if (mounted) {
        // Optional: trigger callback or just let it sit (or fade out)
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (_controller.isCompleted) return const SizedBox.shrink();

        return ShaderMask(
          shaderCallback: (bounds) {
            // 1. Mask the effect to the object shape
            return ImageShader(
              widget.maskImage,
              TileMode.clamp,
              TileMode.clamp,
              (Matrix4.identity()
                    ..scale(
                      bounds.width / widget.maskImage.width,
                      bounds.height / widget.maskImage.height,
                    ))
                  .storage,
            );
          },
          blendMode: BlendMode.dstIn,
          child: ShaderMask(
            shaderCallback: (rect) {
              // 2. Create the scanning gradient
              return LinearGradient(
                begin: Alignment(
                  -2.0 + (_animation.value * 4.0),
                  -0.5,
                ),
                end: Alignment(
                  -1.0 + (_animation.value * 4.0),
                  0.5,
                ),
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcIn,
            child: Container(
              color: Colors.white,
              width: widget.imageSize.width,
              height: widget.imageSize.height,
            ),
          ),
        );
      },
    );
  }
}
