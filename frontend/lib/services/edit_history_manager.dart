import 'package:flutter/foundation.dart';
import '../models/edit_history.dart';

class EditHistoryManager extends ChangeNotifier {
  final List<EditHistoryEntry> _history = [];
  int _currentIndex = -1;

  final int maxHistorySize;

  EditHistoryManager({this.maxHistorySize = 50});

  EditHistoryEntry? get current {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      return _history[_currentIndex];
    }
    return null;
  }

  bool get canUndo => _currentIndex > 0;

  bool get canRedo => _currentIndex < _history.length - 1;

  int get historyCount => _history.length;

  int get currentPosition => _currentIndex;

  List<EditHistoryEntry> get allHistory => List.unmodifiable(_history);

  void addEntry(EditHistoryEntry entry) {
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _history.add(entry);
    _currentIndex = _history.length - 1;

    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }

    notifyListeners();
  }

  EditHistoryEntry? undo() {
    if (!canUndo) return null;

    _currentIndex--;
    notifyListeners();
    return current;
  }

  EditHistoryEntry? redo() {
    if (!canRedo) return null;

    _currentIndex++;
    notifyListeners();
    return current;
  }

  void clear() {
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  EditHistoryEntry? getEntryAt(int index) {
    if (index >= 0 && index < _history.length) {
      return _history[index];
    }
    return null;
  }

  EditHistoryEntry? jumpTo(int index) {
    if (index >= 0 && index < _history.length) {
      _currentIndex = index;
      notifyListeners();
      return current;
    }
    return null;
  }

  String getHistorySummary() {
    final buffer = StringBuffer();
    buffer.writeln('Edit History Summary:');
    buffer.writeln('Total entries: ${_history.length}');
    buffer.writeln('Current position: $_currentIndex');
    buffer.writeln('Can undo: $canUndo');
    buffer.writeln('Can redo: $canRedo');
    buffer.writeln('\nHistory:');

    for (int i = 0; i < _history.length; i++) {
      final entry = _history[i];
      final marker = i == _currentIndex ? '→' : ' ';
      buffer.writeln(
        '$marker [$i] ${entry.type.displayName} - ${entry.timestamp}',
      );
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    _history.clear();
    super.dispose();
  }
}
