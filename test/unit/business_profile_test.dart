import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';

void main() {
  group('BusinessProfile', () {
    test('parses supported storage keys', () {
      expect(
        BusinessProfile.tryParse('mobileOnly'),
        BusinessProfile.mobileOnly,
      );
      expect(
        BusinessProfile.tryParse('mobileAccessories'),
        BusinessProfile.mobileAccessories,
      );
      expect(
        BusinessProfile.tryParse('repairShop'),
        BusinessProfile.repairShop,
      );
      expect(BusinessProfile.tryParse('hybrid'), BusinessProfile.hybrid);
    });

    test('falls back to mobileOnly for missing or unknown values', () {
      expect(BusinessProfile.parseOrDefault(null), BusinessProfile.mobileOnly);
      expect(BusinessProfile.parseOrDefault(''), BusinessProfile.mobileOnly);
      expect(BusinessProfile.parseOrDefault('unknown'), BusinessProfile.mobileOnly);
    });
  });
}
