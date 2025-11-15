import 'dart:io';

class EditHistoryEntry {
  final File imageFile;
  final EditType type;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  EditHistoryEntry({
    required this.imageFile,
    required this.type,
    required this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'EditHistoryEntry(type: $type, timestamp: $timestamp, metadata: $metadata)';
  }
}

enum EditType {
  crop,
  relight,
  reframe,
  filter,
  rotate,
  flip,
  initial,
}

extension EditTypeExtension on EditType {
  String get displayName {
    switch (this) {
      case EditType.crop:
        return 'Crop';
      case EditType.relight:
        return 'Relight';
      case EditType.reframe:
        return 'Reframe';
      case EditType.filter:
        return 'Filter';
      case EditType.rotate:
        return 'Rotate';
      case EditType.flip:
        return 'Flip';
      case EditType.initial:
        return 'Original';
    }
  }

  String get description {
    switch (this) {
      case EditType.crop:
        return 'Image cropped';
      case EditType.relight:
        return 'Lighting adjusted';
      case EditType.reframe:
        return 'Image reframed';
      case EditType.filter:
        return 'Filter applied';
      case EditType.rotate:
        return 'Image rotated';
      case EditType.flip:
        return 'Image flipped';
      case EditType.initial:
        return 'Original image';
    }
  }
}
