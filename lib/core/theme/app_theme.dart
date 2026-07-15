import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_interaction_tokens.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class AppTheme {
  const AppTheme._();

  /// [touch] switches to the touch-friendly density profile (48dp targets,
  /// taller rows, non-dense inputs). Default keeps today's desktop profile.
  static ThemeData light({bool touch = false}) =>
      _buildTheme(Brightness.light, touch: touch);

  static ThemeData dark({bool touch = false}) =>
      _buildTheme(Brightness.dark, touch: touch);

  static ThemeData _buildTheme(Brightness brightness, {required bool touch}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5167F6),
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity:
          touch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: touch ? MaterialTapTargetSize.padded : null,
    );

    final textTheme = AppTypography.build(base.textTheme, colorScheme.onSurface);
    final semanticColors = brightness == Brightness.light
        ? AppSemanticColors.light
        : AppSemanticColors.dark;
    final interactionTokens =
        touch ? AppInteractionTokens.touch : AppInteractionTokens.desktop;

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semanticColors, interactionTokens],
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F8FC)
          : colorScheme.surface,
      cardTheme: CardThemeData(
        // Subtle elevation + soft shadow lifts cards off the canvas instead of
        // the previous flat, paper-thin look. surfaceTintColor is cleared so
        // the card keeps its configured color rather than picking up M3's
        // elevation tint.
        elevation: 1.5,
        shadowColor: brightness == Brightness.light
            ? const Color(0x14101828)
            : Colors.black.withValues(alpha: 0.45),
        surfaceTintColor: Colors.transparent,
        color: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgRadius,
          side: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE3E8F2)
                : colorScheme.outlineVariant,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: !touch,
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
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: touch ? AppSpacing.lg : AppSpacing.md,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdRadius,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: touch ? AppSpacing.lg : AppSpacing.md,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.82)
            : colorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgRadius,
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
        dataRowMinHeight: touch ? 48 : 40,
        // The framework's default max is 48; raise it with the min so
        // dataRowMinHeight <= dataRowMaxHeight always holds.
        dataRowMaxHeight: touch ? 64 : 48,
        dividerThickness: 0.6,
      ),
    );
  }
}
