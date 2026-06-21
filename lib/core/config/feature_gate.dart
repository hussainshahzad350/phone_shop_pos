import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';

typedef FeatureFlagCondition = bool Function(FeatureFlags flags);

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.condition,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final FeatureFlagCondition condition;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(featureFlagsProvider);

    return flagsAsync.when(
      data: (flags) {
        if (condition(flags)) {
          return child;
        }
        return fallback;
      },
      loading: () {
        // Preserve current behavior while loading by using defaults
        const defaults = FeatureFlags.currentBehaviorDefaults();
        if (condition(defaults)) {
          return child;
        }
        return fallback;
      },
      error: (_, __) {
        // Preserve current behavior on error by using defaults
        const defaults = FeatureFlags.currentBehaviorDefaults();
        if (condition(defaults)) {
          return child;
        }
        return fallback;
      },
    );
  }
}
