import 'package:flutter/material.dart';

enum NotificationType {
  info,
  warning,
  error,
  success,
}

class NotificationService extends ChangeNotifier {
  String? _message;
  NotificationType _type = NotificationType.info;
  Widget? _child;
  bool _isVisible = false;

  String? get message => _message;
  NotificationType get type => _type;
  Widget? get child => _child;
  bool get isVisible => _isVisible;

  void show(
    String message, {
    NotificationType type = NotificationType.info,
    Widget? child,
    Duration? duration,
  }) {
    _message = message;
    _type = type;
    _child = child;
    _isVisible = true;
    notifyListeners();

    final autoDismissDuration = duration ?? const Duration(seconds: 3);

    if (autoDismissDuration != Duration.zero) {
      Future.delayed(autoDismissDuration, () {
        if (_isVisible && _message == message) {
          dismiss();
        }
      });
    }
  }

  void dismiss() {
    _isVisible = false;
    notifyListeners();
  }
}
