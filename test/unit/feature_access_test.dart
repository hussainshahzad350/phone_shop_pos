import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';

void main() {
  group('routeEnabledForProfile', () {
    test('all routes are enabled for every profile', () {
      const routes = <String>[
        '/dashboard',
        '/sales',
        '/purchases',
        '/inventory',
        '/repairing',
        '/reports',
        '/settings',
        '/dealer-issues',
      ];
      for (final profile in BusinessProfile.values) {
        for (final route in routes) {
          expect(
            routeEnabledForProfile(path: route, profile: profile),
            isTrue,
            reason: '$route should be enabled for $profile',
          );
        }
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
