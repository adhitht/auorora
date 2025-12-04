import 'package:flutter/material.dart';
import 'light_paint_stroke.dart';

class RelightEditorController extends ChangeNotifier {
  final List<LightPaintStroke> _strokes = [];
  
  List<LightPaintStroke> get strokes => List.unmodifiable(_strokes);

  void addLight({
    required Offset position, // Normalized 0-1
    required Color color,
    required double intensity,
    required double radius,
    bool isSpot = true,
  }) {
    _strokes.add(
      LightPaintStroke(
        points: [position],
        color: color,
        brightness: intensity,
        width: radius,
        type: isSpot ? LightPaintType.spot : LightPaintType.brush,
      ),
    );
    notifyListeners();
  }

  void clearLights() {
    _strokes.clear();
    notifyListeners();
  }
  
  // Method to sync strokes from the widget (user interaction) back to controller
  void updateStrokes(List<LightPaintStroke> newStrokes) {
    _strokes.clear();
    _strokes.addAll(newStrokes);
    // No notifyListeners here to avoid loops if called from widget build/state
  }
}
