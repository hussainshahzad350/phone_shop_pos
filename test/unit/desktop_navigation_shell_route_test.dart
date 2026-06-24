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

    test('omits repairing from navigation for non-repair profiles', () {
      final mobileOnlyItems =
          desktopNavigationItemsForProfile(BusinessProfile.mobileOnly);
      final accessoriesItems =
          desktopNavigationItemsForProfile(BusinessProfile.mobileAccessories);

      expect(mobileOnlyItems.map((i) => i.route),
          isNot(contains('/repairing')));
      expect(accessoriesItems.map((i) => i.route),
          isNot(contains('/repairing')));
      expect(mobileOnlyItems.map((i) => i.route), contains('/dashboard'));
      expect(mobileOnlyItems.map((i) => i.route), contains('/settings'));
    });

    test('includes repairing in navigation for repair and hybrid profiles', () {
      final repairItems =
          desktopNavigationItemsForProfile(BusinessProfile.repairShop);
      final hybridItems =
          desktopNavigationItemsForProfile(BusinessProfile.hybrid);

      expect(repairItems.map((i) => i.route), contains('/repairing'));
      expect(hybridItems.map((i) => i.route), contains('/repairing'));
    });

    test('falls back to dashboard index when current route is not in nav', () {
      expect(
        desktopNavigationSelectedIndexForPath(
          '/repairing',
          profile: BusinessProfile.mobileOnly,
        ),
        0,
      );
    });
  });
}
