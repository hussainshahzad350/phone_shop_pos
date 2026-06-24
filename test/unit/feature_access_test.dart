import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';

void main() {
  group('routeEnabledForProfile', () {
    test('repairing only enabled for repairShop and hybrid', () {
      expect(
        routeEnabledForProfile(
            path: '/repairing', profile: BusinessProfile.mobileOnly),
        isFalse,
      );
      expect(
        routeEnabledForProfile(
            path: '/repairing', profile: BusinessProfile.mobileAccessories),
        isFalse,
      );
      expect(
        routeEnabledForProfile(
            path: '/repairing', profile: BusinessProfile.repairShop),
        isTrue,
      );
      expect(
        routeEnabledForProfile(
            path: '/repairing', profile: BusinessProfile.hybrid),
        isTrue,
      );
    });

    test('nested repairing path follows the same rule', () {
      expect(
        routeEnabledForProfile(
            path: '/repairing/jobs/123',
            profile: BusinessProfile.mobileOnly),
        isFalse,
      );
      expect(
        routeEnabledForProfile(
            path: '/repairing/jobs/123', profile: BusinessProfile.hybrid),
        isTrue,
      );
    });

    test('reports and inventory are enabled for all profiles', () {
      for (final profile in BusinessProfile.values) {
        expect(
          routeEnabledForProfile(path: '/reports', profile: profile),
          isTrue,
          reason: 'reports should be enabled for $profile',
        );
        expect(
          routeEnabledForProfile(path: '/inventory', profile: profile),
          isTrue,
          reason: 'inventory should be enabled for $profile',
        );
      }
    });

    test('other routes are always enabled regardless of profile', () {
      for (final profile in BusinessProfile.values) {
        expect(
          routeEnabledForProfile(path: '/dashboard', profile: profile),
          isTrue,
        );
        expect(
          routeEnabledForProfile(path: '/settings', profile: profile),
          isTrue,
        );
        expect(
          routeEnabledForProfile(path: '/sales', profile: profile),
          isTrue,
        );
      }
    });
  });

  group('profileRouteFallback', () {
    test('returns dashboard for all profiles', () {
      for (final profile in BusinessProfile.values) {
        expect(profileRouteFallback(profile), '/dashboard');
      }
    });
  });
}
