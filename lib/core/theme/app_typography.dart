import 'package:flutter/material.dart';

/// Explicit Material 3 type scale for the app.
///
/// Previously the app relied entirely on Flutter's default [TextTheme] and
/// sprinkled `fontWeight: FontWeight.bold` ad hoc. This builds a deliberate
/// scale (display → label) layered onto the platform default font, so headings,
/// section titles, table headers and body text have consistent size/weight
/// semantics. Numeric/financial widgets can opt into [tabularFigures] so digits
/// align in columns.
abstract final class AppTypography {
  /// Enables tabular (monospaced) figures so currency columns line up.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme build(TextTheme base, Color color) {
    final muted = color.withValues(alpha: 0.72);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: muted,
      ),
    );
  }
}
