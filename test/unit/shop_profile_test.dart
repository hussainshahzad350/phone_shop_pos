import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/config/shop_profile.dart';

void main() {
  group('ShopProfile', () {
    test('encode/tryParse round-trips all fields', () {
      const profile = ShopProfile(
        shopName: 'Ali Mobiles',
        phone: '0300-1234567',
        email: 'ali@example.com',
        address: 'Hall Road, Lahore',
        footerNote: 'No returns after 7 days',
      );

      final parsed = ShopProfile.tryParse(profile.encode());

      expect(parsed, profile);
    });

    test('tryParse returns null for malformed or empty input', () {
      expect(ShopProfile.tryParse(null), isNull);
      expect(ShopProfile.tryParse(''), isNull);
      expect(ShopProfile.tryParse('not json'), isNull);
      // Valid JSON but missing a shop name is treated as unusable.
      expect(ShopProfile.tryParse('{"phone":"123"}'), isNull);
    });

    test('unconfigured falls back to the app display name with empty contacts',
        () {
      final profile = ShopProfile.unconfigured();

      expect(profile.shopName, isNotEmpty);
      expect(profile.phone, isEmpty);
      expect(profile.email, isEmpty);
      expect(profile.address, isEmpty);
      expect(profile.footerNote, isNull);
    });

    test('copyWith can clear the footer note', () {
      const profile = ShopProfile(
        shopName: 'Ali Mobiles',
        phone: '',
        email: '',
        address: '',
        footerNote: 'temp',
      );

      final cleared = profile.copyWith(clearFooterNote: true);

      expect(cleared.footerNote, isNull);
    });
  });
}
