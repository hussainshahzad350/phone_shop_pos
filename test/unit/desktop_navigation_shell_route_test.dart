import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
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

    test('all nav items are shown for every profile', () {
      for (final profile in BusinessProfile.values) {
        final items = desktopNavigationItemsForProfile(profile);
        expect(items.map((i) => i.route), contains('/repairing'));
        expect(items.map((i) => i.route), contains('/reports'));
        expect(items.map((i) => i.route), contains('/dashboard'));
        expect(items.map((i) => i.route), contains('/settings'));
      }
    });
  });
}
