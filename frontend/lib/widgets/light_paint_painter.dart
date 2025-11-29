import 'package:flutter/material.dart';
import 'light_paint_stroke.dart';

class LightPaintPainter extends CustomPainter {
  final List<LightPaintStroke> strokes;

  LightPaintPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      if (stroke.type == LightPaintType.spot) {
        // Draw Spot
        final center = Offset(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
        
        // Outer glow
        final glowPaint = Paint()
          ..color = stroke.color.withOpacity(stroke.brightness * 0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
          
        canvas.drawCircle(center, stroke.width * 1.5, glowPaint);
        
        // Core
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          
        canvas.drawCircle(center, stroke.width * 0.5, corePaint);
        
      } else {
        // Draw Brush Stroke
        final paint = Paint()
          ..color = stroke.color.withOpacity(stroke.brightness)
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10); // Glow effect

        // Draw path
        final path = Path();
        // Points are normalized (0..1), so scale to canvas size
        final firstPoint = Offset(stroke.points.first.dx * size.width, stroke.points.first.dy * size.height);
        path.moveTo(firstPoint.dx, firstPoint.dy);
        
        for (int i = 1; i < stroke.points.length; i++) {
          final point = Offset(stroke.points[i].dx * size.width, stroke.points[i].dy * size.height);
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
        
        // Draw core (brighter center)
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(stroke.brightness * 0.8)
          ..strokeWidth = stroke.width * 0.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
          
        canvas.drawPath(path, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LightPaintPainter oldDelegate) {
    return true; // Always repaint for now, can optimize later
  }
}
