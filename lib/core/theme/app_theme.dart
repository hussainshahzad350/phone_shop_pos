import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    // Corporate navy from the POS Dashboard v2 design mockup.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2455A4),
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
    );

    final textTheme = AppTypography.build(base.textTheme, colorScheme.onSurface);
    final semanticColors = brightness == Brightness.light
        ? AppSemanticColors.light
        : AppSemanticColors.dark;

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F8FC)
          : colorScheme.surface,
      cardTheme: CardThemeData(
        // Flat, hairline-bordered cards per the POS Dashboard v2 mockup:
        // solid surface, no shadow, medium radius. surfaceTintColor is
        // cleared so the card keeps its configured color rather than picking
        // up M3's elevation tint.
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: brightness == Brightness.light
            ? Colors.white
            : Colors.white.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdRadius,
          side: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE3E8F2)
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
          borderRadius: AppRadii.lgRadius,
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFD7DBE7)
                : colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgRadius,
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFD7DBE7)
                : colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdRadius,
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.82)
            : colorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: AppRadii.smRadius,
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
        headingTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        dataRowMinHeight: 40,
        dividerThickness: 0.6,
      ),
    );
  }
}
