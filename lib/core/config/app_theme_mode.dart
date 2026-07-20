import 'package:flutter/material.dart';

/// User-selectable appearance mode, persisted in `app_settings`.
///
/// [system] follows the operating system's light/dark preference and is the
/// default so existing installs keep `MaterialApp`'s original behaviour.
enum AppThemeMode {
  system,
  light,
  dark;

  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  /// Maps to the Flutter [ThemeMode] consumed by `MaterialApp`.
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  static AppThemeMode fromString(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}
