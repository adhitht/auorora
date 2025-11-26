import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const LoadingIndicator({
    super.key,
    this.size = 50.0,
    this.color = Colors.white,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SimpleRingPainter(
              color: widget.color,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _SimpleRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _SimpleRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    // Draw background ring
    canvas.drawCircle(center, radius, paint);

    // Draw rotating arc
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2 + (progress * 2 * math.pi);
    const sweepAngle = math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
    
    // Draw inner pulsing dot
    final dotPaint = Paint()
      ..color = color.withOpacity(0.5 + (math.sin(progress * 2 * math.pi) * 0.3))
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(center, radius * 0.3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SimpleRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
