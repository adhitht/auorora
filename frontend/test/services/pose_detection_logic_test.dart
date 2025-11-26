import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex/services/pose_detection_service.dart';

void main() {
  group('PoseDetectionService Coordinate Transformation', () {
    const inputSize = 192;

    test('Square image (no padding)', () {
      const originalWidth = 1000.0;
      const originalHeight = 1000.0;
      const scale = 0.192; // 192 / 1000
      const paddingX = 0.0;
      const paddingY = 0.0;

      // Center point
      final result = PoseDetectionService.calculateOriginalCoordinate(
        0.5,
        0.5,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );

      expect(result.x, closeTo(0.5, 0.001));
      expect(result.y, closeTo(0.5, 0.001));

      // Top-Left
      final resultTL = PoseDetectionService.calculateOriginalCoordinate(
        0.0,
        0.0,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );
      expect(resultTL.x, closeTo(0.0, 0.001));
      expect(resultTL.y, closeTo(0.0, 0.001));
    });

    test('Portrait image (padding on X)', () {
      const originalWidth = 1000.0;
      const originalHeight = 2000.0;
      // Scale based on height: 192 / 2000 = 0.096
      const scale = 0.096;
      // New Width: 1000 * 0.096 = 96
      // Padding X: (192 - 96) / 2 = 48
      const paddingX = 48.0;
      const paddingY = 0.0;

      // Top-Left of actual image (inside letterbox)
      // In tensor coords: x = 48, y = 0
      // Normalized: x = 48/192 = 0.25, y = 0
      final resultTL = PoseDetectionService.calculateOriginalCoordinate(
        0.25,
        0.0,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );
      expect(resultTL.x, closeTo(0.0, 0.001));
      expect(resultTL.y, closeTo(0.0, 0.001));

      // Bottom-Right of actual image
      // In tensor coords: x = 48 + 96 = 144, y = 192
      // Normalized: x = 144/192 = 0.75, y = 1.0
      final resultBR = PoseDetectionService.calculateOriginalCoordinate(
        0.75,
        1.0,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );
      expect(resultBR.x, closeTo(1.0, 0.001));
      expect(resultBR.y, closeTo(1.0, 0.001));
    });

    test('Landscape image (padding on Y)', () {
      const originalWidth = 2000.0;
      const originalHeight = 1000.0;
      // Scale based on width: 192 / 2000 = 0.096
      const scale = 0.096;
      // New Height: 1000 * 0.096 = 96
      // Padding Y: (192 - 96) / 2 = 48
      const paddingX = 0.0;
      const paddingY = 48.0;

      // Top-Left of actual image
      // In tensor coords: x = 0, y = 48
      // Normalized: x = 0, y = 48/192 = 0.25
      final resultTL = PoseDetectionService.calculateOriginalCoordinate(
        0.0,
        0.25,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );
      expect(resultTL.x, closeTo(0.0, 0.001));
      expect(resultTL.y, closeTo(0.0, 0.001));

      // Bottom-Right of actual image
      // In tensor coords: x = 192, y = 48 + 96 = 144
      // Normalized: x = 1.0, y = 144/192 = 0.75
      final resultBR = PoseDetectionService.calculateOriginalCoordinate(
        1.0,
        0.75,
        paddingX,
        paddingY,
        scale,
        originalWidth,
        originalHeight,
        inputSize,
      );
      expect(resultBR.x, closeTo(1.0, 0.001));
      expect(resultBR.y, closeTo(1.0, 0.001));
    });
  });
}
