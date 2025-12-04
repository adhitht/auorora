import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/relight_editor_controller.dart';

class PipelineExecutor {
  Future<void> execute(
    Map<String, dynamic> command,
    RelightEditorController controller,
  ) async {
    final action = command['action'] as String?;
    if (action != 'relight') return;

    final params = command['params'] as Map<String, dynamic>?;
    if (params == null) return;

    // Clear existing lights if requested (optional, but good for clean state)
    controller.clearLights();

    final lights = params['lights'] as List<dynamic>?;
    if (lights != null) {
      for (final light in lights) {
        final type = light['type'] as String? ?? 'spot';
        final positionMap = light['position'] as Map<String, dynamic>?;
        final colorHex = light['color'] as String? ?? '#FFFFFF';
        final intensity = (light['intensity'] as num?)?.toDouble() ?? 0.8;
        final radius = (light['radius'] as num?)?.toDouble() ?? 30.0;

        if (positionMap != null) {
          final x = (positionMap['x'] as num).toDouble().clamp(0.0, 1.0);
          final y = (positionMap['y'] as num).toDouble().clamp(0.0, 1.0);
          
          final color = _hexToColor(colorHex);

          controller.addLight(
            position: Offset(x, y),
            color: color,
            intensity: intensity,
            radius: radius,
            isSpot: type == 'spot',
          );
        }
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
