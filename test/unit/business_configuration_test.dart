import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';

void main() {
  group('BusinessConfiguration', () {
    test('defaults to mobileOnly profile with defaultValue source', () {
      final configuration = BusinessConfiguration.defaults();

      expect(configuration.profile, BusinessProfile.mobileOnly);
      expect(
        configuration.source,
        BusinessConfigurationSource.defaultValue,
      );
      expect(
        configuration.schemaVersion,
        BusinessConfiguration.currentSchemaVersion,
      );
    });

    test('copyWith overrides only the specified fields', () {
      final original = BusinessConfiguration.defaults();
      final updated = original.copyWith(profile: BusinessProfile.hybrid);

      expect(updated.profile, BusinessProfile.hybrid);
      expect(updated.source, original.source);
      expect(updated.schemaVersion, original.schemaVersion);
    });
  });
}
