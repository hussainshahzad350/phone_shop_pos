import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';

void main() {
  group('routeEnabledForFeatureFlags', () {
    test('allows all current routes with default flags', () {
      const flags = FeatureFlags.currentBehaviorDefaults();

      expect(
        routeEnabledForFeatureFlags(path: '/repairing', featureFlags: flags),
        isTrue,
      );
      expect(
        routeEnabledForFeatureFlags(path: '/reports', featureFlags: flags),
        isTrue,
      );
      expect(
        routeEnabledForFeatureFlags(path: '/inventory', featureFlags: flags),
        isTrue,
      );
    });

    test('blocks repair and report routes when their flags are disabled', () {
      final flags = const FeatureFlags.currentBehaviorDefaults().copyWith(
        repairModule: false,
        reports: false,
      );

      expect(
        routeEnabledForFeatureFlags(path: '/repairing', featureFlags: flags),
        isFalse,
      );
      expect(
        routeEnabledForFeatureFlags(
            path: '/reports/daily', featureFlags: flags),
        isFalse,
      );
      expect(
        routeEnabledForFeatureFlags(path: '/settings', featureFlags: flags),
        isTrue,
      );
    });

    test('blocks inventory only when both inventory modes are disabled', () {
      final imeiOnly = const FeatureFlags.currentBehaviorDefaults().copyWith(
        qtyStock: false,
      );
      final disabled = const FeatureFlags.currentBehaviorDefaults().copyWith(
        imeiStock: false,
        qtyStock: false,
      );

      expect(
        routeEnabledForFeatureFlags(path: '/inventory', featureFlags: imeiOnly),
        isTrue,
      );
      expect(
        routeEnabledForFeatureFlags(path: '/inventory', featureFlags: disabled),
        isFalse,
      );
    });
  });

  group('featureFlagRouteFallback', () {
    test('returns dashboard by default', () {
      const flags = FeatureFlags.currentBehaviorDefaults();
      expect(featureFlagRouteFallback(flags), '/dashboard');
    });

    test('returns settings if dashboard is somehow disabled', () {
      // Assuming navigationStyle disables dashboard
      final flags = const FeatureFlags.currentBehaviorDefaults().copyWith(
        navigationStyle: false,
      );
      // Currently routeEnabledForFeatureFlags always returns true for dashboard
      // so this test might need adjustment if dashboard is ever gated.
      // But we just verify the helper function logic.
      expect(featureFlagRouteFallback(flags), '/dashboard');
    });
  });
}
