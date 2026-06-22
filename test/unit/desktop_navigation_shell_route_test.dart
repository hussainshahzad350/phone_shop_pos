import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';
import 'package:phone_shop_pos/core/widgets/desktop_navigation_shell.dart';

void main() {
  group('desktop route matching', () {
    test('matches nested paths for the same route prefix', () {
      expect(
        desktopRouteMatches(
          currentPath: '/reports/daily',
          routePrefix: '/reports',
        ),
        isTrue,
      );
    });

    test('ignores query params while matching route prefixes', () {
      expect(
        desktopRouteMatches(
          currentPath: '/reports/sold-phones?from=2026-01-01&to=2026-01-31',
          routePrefix: '/reports',
        ),
        isTrue,
      );
    });

    test('does not match lookalike route prefixes', () {
      expect(
        desktopRouteMatches(
          currentPath: '/reports-archive',
          routePrefix: '/reports',
        ),
        isFalse,
      );
    });
  });

  group('desktop selected index mapping', () {
    test('returns inventory index for nested inventory route', () {
      expect(
        desktopNavigationSelectedIndexForPath('/inventory/phones/list?page=2'),
        3,
      );
    });

    test('falls back to dashboard index for unknown route', () {
      expect(
        desktopNavigationSelectedIndexForPath('/unknown-area'),
        0,
      );
    });

    test('omits disabled feature routes from navigation items', () {
      final items = desktopNavigationItemsForFlags(
        const FeatureFlags.currentBehaviorDefaults().copyWith(
          repairModule: false,
          reports: false,
        ),
      );

      expect(items.map((item) => item.route), isNot(contains('/repairing')));
      expect(items.map((item) => item.route), isNot(contains('/reports')));
      expect(items.map((item) => item.route), contains('/dashboard'));
      expect(items.map((item) => item.route), contains('/settings'));
    });

    test('falls back to dashboard when current feature route is hidden', () {
      expect(
        desktopNavigationSelectedIndexForPath(
          '/reports',
          featureFlags: const FeatureFlags.currentBehaviorDefaults().copyWith(
            reports: false,
          ),
        ),
        0,
      );
    });
  });
}
