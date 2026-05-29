import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/user_facing_errors.dart';

enum AppNotificationType { success, error, warning, info }

class AppNotifier {
  AppNotifier._();

  static const Duration _successDuration = Duration(seconds: 3);
  static const Duration _errorDuration = Duration(seconds: 6);
  static const Duration _warningDuration = Duration(seconds: 5);
  static const Duration _infoDuration = Duration(seconds: 4);

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(
    String message, {
    SnackBarAction? action,
    bool showCloseIcon = false,
    Duration duration = _successDuration,
  }) {
    _show(
      message,
      AppNotificationType.success,
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void error(
    String message, {
    SnackBarAction? action,
    bool showCloseIcon = true,
    Duration duration = _errorDuration,
  }) {
    _show(
      message,
      AppNotificationType.error,
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void errorFrom(
    Object source, {
    String? operation,
    SnackBarAction? action,
    bool showCloseIcon = true,
    Duration duration = _errorDuration,
  }) {
    AppNotifier.error(
      UserFacingErrors.messageFor(source, operation: operation),
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void errorFromAppError(
    AppError appError, {
    SnackBarAction? action,
    bool showCloseIcon = true,
    Duration duration = _errorDuration,
  }) {
    AppNotifier.error(
      UserFacingErrors.messageForAppError(appError),
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void warning(
    String message, {
    SnackBarAction? action,
    bool showCloseIcon = false,
    Duration duration = _warningDuration,
  }) {
    _show(
      message,
      AppNotificationType.warning,
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void info(
    String message, {
    SnackBarAction? action,
    bool showCloseIcon = false,
    Duration duration = _infoDuration,
  }) {
    _show(
      message,
      AppNotificationType.info,
      action: action,
      showCloseIcon: showCloseIcon,
      duration: duration,
    );
  }

  static void _show(
    String message,
    AppNotificationType type, {
    SnackBarAction? action,
    bool showCloseIcon = false,
    required Duration duration,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    final effectiveShowCloseIcon = showCloseIcon || action != null;

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
          duration: duration,
          action: action,
          showCloseIcon: effectiveShowCloseIcon,
          closeIconColor: Colors.white,
        ),
      );
  }
}
