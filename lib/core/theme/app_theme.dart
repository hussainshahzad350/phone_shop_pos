import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5167F6),
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F8FC)
          : colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.94)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFD9DFEC)
                : colorScheme.outlineVariant,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFFAFBFE)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFD7DBE7)
                : colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFD7DBE7)
                : colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.82)
            : colorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minWidth: 76,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 0.8,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color?>(
          brightness == Brightness.light
              ? const Color(0xFFEFF2FA)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        headingTextStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        dataRowMinHeight: 40,
        dividerThickness: 0.6,
      ),
    );
  }
}
