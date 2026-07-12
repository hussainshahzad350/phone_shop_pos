import 'package:flutter/animation.dart';

/// Shared animation/timing constants. Centralizes the durations and curves
/// that were previously hardcoded independently per widget so the app's
/// motion language has one source of truth — new widgets should pick one of
/// these rather than inventing another one-off value.
///
/// Existing values are preserved exactly as they were before consolidation;
/// this only removes duplication, it does not retune any animation.
abstract final class AppMotion {
  /// Content-switch fades (e.g. AppDesktopScaffold's body AnimatedSwitcher).
  static const Duration contentSwitch = Duration(milliseconds: 180);

  /// Standard eased motion — quick-bar scroll-step animation and product/
  /// purchase card transitions.
  static const Duration standardTransition = Duration(milliseconds: 250);
  static const Curve standardTransitionCurve = Curves.easeOutCubic;

  /// Loading-skeleton shimmer sweep.
  static const Duration skeletonShimmer = Duration(milliseconds: 1100);
  static const Curve skeletonShimmerCurve = Curves.easeInOut;

  /// Default debounce for search-as-you-type fields.
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// Faster debounce for latency-sensitive scanner-driven search (IMEI picker).
  static const Duration fastDebounce = Duration(milliseconds: 150);

  /// Periodic idle-check interval for the global barcode-scanner listener.
  static const Duration scannerIdlePoll = Duration(milliseconds: 500);
}
