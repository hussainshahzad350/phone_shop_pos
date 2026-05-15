import 'package:flutter/material.dart';

enum AppNotificationType { success, error, warning, info }

class AppNotifier {
  AppNotifier._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(String message, {SnackBarAction? action}) {
    _show(message, AppNotificationType.success, action: action);
  }

  static void error(String message, {SnackBarAction? action}) {
    _show(message, AppNotificationType.error, action: action);
  }

  static void warning(String message, {SnackBarAction? action}) {
    _show(message, AppNotificationType.warning, action: action);
  }

  static void info(String message, {SnackBarAction? action}) {
    _show(message, AppNotificationType.info, action: action);
  }

  static void _show(
    String message,
    AppNotificationType type, {
    SnackBarAction? action,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }

    final color = switch (type) {
      AppNotificationType.success => Colors.green.shade700,
      AppNotificationType.error => Colors.red.shade700,
      AppNotificationType.warning => Colors.orange.shade800,
      AppNotificationType.info => Colors.blueGrey.shade700,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: action,
        ),
      );
  }
}
