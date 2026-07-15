import 'package:flutter/material.dart';

/// Sizing tokens for interactive controls that differ between the desktop
/// profile (compact, mouse-precision targets — today's defaults) and the
/// touch profile (Material-compliant 48dp targets).
///
/// Widgets that hardcoded desktop-density literals (18px row-action icons,
/// `Size.zero` minimum buttons, `VisualDensity.compact` steppers) read these
/// via `AppInteractionTokens.of(context)` instead. The desktop set matches the
/// previous literals exactly, so with Touch mode off nothing changes — and
/// widgets pumped under a bare [MaterialApp] (tests) fall back to desktop.
@immutable
class AppInteractionTokens extends ThemeExtension<AppInteractionTokens> {
  const AppInteractionTokens({
    required this.isTouch,
    required this.rowActionIconSize,
    required this.rowActionGap,
    required this.controlDensity,
    required this.minButtonSize,
    required this.tapTargetSize,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
  });

  /// Whether the touch profile is active. Lets widgets make behavioral
  /// choices (e.g. tap feedback for disabled controls) without watching the
  /// settings provider directly.
  final bool isTouch;

  /// Icon size for icon buttons embedded in table rows.
  final double rowActionIconSize;

  /// Horizontal gap between adjacent row-action icon buttons.
  final double rowActionGap;

  /// Density for compact inline controls (steppers, row actions).
  final VisualDensity controlDensity;

  /// Minimum size for buttons that previously shrank to their content.
  final Size minButtonSize;

  /// Tap target inflation for chips/buttons that previously shrink-wrapped.
  final MaterialTapTargetSize tapTargetSize;

  /// Floor for data table row heights (min/max raised together — the
  /// framework asserts min <= max).
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  /// Matches the literals used across the app before Touch mode existed.
  static const AppInteractionTokens desktop = AppInteractionTokens(
    isTouch: false,
    rowActionIconSize: 18,
    rowActionGap: 6,
    controlDensity: VisualDensity.compact,
    minButtonSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    dataRowMinHeight: 40,
    dataRowMaxHeight: 48,
  );

  static const AppInteractionTokens touch = AppInteractionTokens(
    isTouch: true,
    rowActionIconSize: 22,
    rowActionGap: 10,
    controlDensity: VisualDensity.standard,
    minButtonSize: Size(48, 48),
    tapTargetSize: MaterialTapTargetSize.padded,
    dataRowMinHeight: 48,
    dataRowMaxHeight: 64,
  );

  static AppInteractionTokens of(BuildContext context) {
    return Theme.of(context).extension<AppInteractionTokens>() ??
        AppInteractionTokens.desktop;
  }

  @override
  AppInteractionTokens copyWith({
    bool? isTouch,
    double? rowActionIconSize,
    double? rowActionGap,
    VisualDensity? controlDensity,
    Size? minButtonSize,
    MaterialTapTargetSize? tapTargetSize,
    double? dataRowMinHeight,
    double? dataRowMaxHeight,
  }) {
    return AppInteractionTokens(
      isTouch: isTouch ?? this.isTouch,
      rowActionIconSize: rowActionIconSize ?? this.rowActionIconSize,
      rowActionGap: rowActionGap ?? this.rowActionGap,
      controlDensity: controlDensity ?? this.controlDensity,
      minButtonSize: minButtonSize ?? this.minButtonSize,
      tapTargetSize: tapTargetSize ?? this.tapTargetSize,
      dataRowMinHeight: dataRowMinHeight ?? this.dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight ?? this.dataRowMaxHeight,
    );
  }

  @override
  AppInteractionTokens lerp(
    covariant ThemeExtension<AppInteractionTokens>? other,
    double t,
  ) {
    if (other is! AppInteractionTokens) {
      return this;
    }
    // Discrete values (bool, enum, density) switch at the midpoint; numeric
    // sizes interpolate so the theme change animates smoothly.
    final target = t < 0.5 ? this : other;
    return AppInteractionTokens(
      isTouch: target.isTouch,
      rowActionIconSize:
          lerpDouble(rowActionIconSize, other.rowActionIconSize, t),
      rowActionGap: lerpDouble(rowActionGap, other.rowActionGap, t),
      controlDensity: target.controlDensity,
      minButtonSize: Size.lerp(minButtonSize, other.minButtonSize, t)!,
      tapTargetSize: target.tapTargetSize,
      dataRowMinHeight: lerpDouble(dataRowMinHeight, other.dataRowMinHeight, t),
      dataRowMaxHeight: lerpDouble(dataRowMaxHeight, other.dataRowMaxHeight, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
