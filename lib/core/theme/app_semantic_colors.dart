import 'package:flutter/material.dart';

/// Semantic status colors that are NOT part of Material's [ColorScheme].
///
/// The app expresses success / warning / danger / info states in many places
/// (KPI cards, stock badges, ledger balances, repair statuses). Before this
/// extension those were hardcoded `Colors.green` / `Colors.orange` literals per
/// widget, which (a) don't adapt to dark mode and (b) drift in shade between
/// screens. Pull from `Theme.of(context).extension<AppSemanticColors>()!`
/// instead, or via the [AppSemanticColorsX] helper.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF1B873F),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD7F4DF),
    warning: Color(0xFFB7791F),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFCEBC9),
    danger: Color(0xFFD13438),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFFBDADB),
    info: Color(0xFF2F6FED),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDBE7FE),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF5CCB7A),
    onSuccess: Color(0xFF06310F),
    successContainer: Color(0xFF154D26),
    warning: Color(0xFFE3B341),
    onWarning: Color(0xFF3A2A05),
    warningContainer: Color(0xFF5C460F),
    danger: Color(0xFFF2787C),
    onDanger: Color(0xFF40090B),
    dangerContainer: Color(0xFF66191C),
    info: Color(0xFF7BA6F5),
    onInfo: Color(0xFF06204F),
    infoContainer: Color(0xFF1D3B72),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

/// Ergonomic access: `Theme.of(context).semantic.success`.
extension AppSemanticColorsX on ThemeData {
  AppSemanticColors get semantic =>
      extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
