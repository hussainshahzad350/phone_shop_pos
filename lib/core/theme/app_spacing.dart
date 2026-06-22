import 'package:flutter/widgets.dart';

/// Spacing and radius design tokens.
///
/// Every `EdgeInsets`/`SizedBox`/`BorderRadius` in the app should reference
/// these instead of inlining magic numbers, so density stays consistent across
/// screens. Scale is a 4px grid: 4 / 8 / 12 / 16 / 24 / 32.
abstract final class AppSpacing {
  /// 4 — hairline gaps between tightly-coupled elements (icon ↔ label).
  static const double xs = 4;

  /// 8 — default gap between sibling controls.
  static const double sm = 8;

  /// 12 — inner padding for compact cards/list tiles.
  static const double md = 12;

  /// 16 — standard card/section padding.
  static const double lg = 16;

  /// 24 — comfortable screen-content padding (desktop default).
  static const double xl = 24;

  /// 32 — large separations between major page regions.
  static const double xxl = 32;

  // Common pre-built edge insets to avoid re-allocating in build methods.
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  // Common pre-built gap boxes.
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
}

/// Corner-radius design tokens. Cards, inputs, chips and dialogs should pull
/// from one of these so radii read as a deliberate scale, not per-widget guesses.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
}
