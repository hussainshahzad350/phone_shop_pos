import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';

void main() {
  group('BusinessProfile', () {
    test('parses supported storage keys', () {
      expect(
        BusinessProfile.tryParse('mobile_only'),
        BusinessProfile.mobileOnly,
      );
      expect(
        BusinessProfile.tryParse('mobile_accessories'),
        BusinessProfile.mobileAccessories,
      );
      expect(
        BusinessProfile.tryParse('repair_shop'),
        BusinessProfile.repairShop,
      );
      expect(BusinessProfile.tryParse('hybrid'), BusinessProfile.hybrid);
    });

    test('falls back to hybrid for missing or unknown values', () {
      expect(BusinessProfile.parseOrDefault(null), BusinessProfile.hybrid);
      expect(BusinessProfile.parseOrDefault(''), BusinessProfile.hybrid);
      expect(BusinessProfile.parseOrDefault('unknown'), BusinessProfile.hybrid);
    });
  });
}
