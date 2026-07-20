import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/app_theme_mode.dart';

void main() {
  group('AppThemeMode.fromString', () {
    test('maps stored keys back to their enum value', () {
      expect(AppThemeMode.fromString('light'), AppThemeMode.light);
      expect(AppThemeMode.fromString('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromString('system'), AppThemeMode.system);
    });

    test('defaults to system for null or unknown values', () {
      expect(AppThemeMode.fromString(null), AppThemeMode.system);
      expect(AppThemeMode.fromString(''), AppThemeMode.system);
      expect(AppThemeMode.fromString('midnight'), AppThemeMode.system);
    });

    test('round-trips through the persisted name', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromString(mode.name), mode);
      }
    });
  });

  group('AppThemeMode.themeMode', () {
    test('maps to the matching Flutter ThemeMode', () {
      expect(AppThemeMode.system.themeMode, ThemeMode.system);
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
    });
  });

  group('AppThemeMode.displayName', () {
    test('every mode exposes a non-empty label', () {
      for (final mode in AppThemeMode.values) {
        expect(mode.displayName, isNotEmpty);
      }
    });
  });
}
