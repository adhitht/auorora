class PoseLandmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  @override
  String toString() {
    return 'PoseLandmark(x: $x, y: $y, z: $z, visibility: $visibility)';
  }
}

class PoseDetectionResult {
  final List<PoseLandmark> landmarks;
  final double confidence;

  PoseDetectionResult({required this.landmarks, required this.confidence});

  PoseLandmark? getLandmark(PoseLandmarkType type) {
    final idx = type.landmarkIndex;
    if (idx >= 0 && idx < landmarks.length) {
      return landmarks[idx];
    }
    return null;
  }
}

enum PoseLandmarkType {
  nose(0),
  leftEye(1),
  rightEye(2),
  leftEar(3),
  rightEar(4),
  leftShoulder(5),
  rightShoulder(6),
  leftElbow(7),
  rightElbow(8),
  leftWrist(9),
  rightWrist(10),
  leftHip(11),
  rightHip(12),
  leftKnee(13),
  rightKnee(14),
  leftAnkle(15),
  rightAnkle(16);

  final int landmarkIndex;
  const PoseLandmarkType(this.landmarkIndex);
}
