import 'dart:ui';

enum LightPaintType {
  brush,
  spot,
}

class LightPaintStroke {
  final List<Offset> points;
  final Color color;
  final double brightness;
  final double width;
  final LightPaintType type;

  LightPaintStroke({
    required this.points,
    required this.color,
    required this.brightness,
    required this.width,
    this.type = LightPaintType.brush,
  });
}
