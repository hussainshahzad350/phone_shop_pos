import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';

void main() {
  group('BusinessConfiguration', () {
    test('defaults preserve current behavior', () {
      final configuration = BusinessConfiguration.defaults();

      expect(configuration.profile, BusinessProfile.hybrid);
      expect(
        configuration.featureFlags,
        const FeatureFlags.currentBehaviorDefaults(),
      );
      expect(
        configuration.source,
        BusinessConfigurationSource.defaultValue,
      );
      expect(
        configuration.schemaVersion,
        BusinessConfiguration.currentSchemaVersion,
      );
    });
  });
}
