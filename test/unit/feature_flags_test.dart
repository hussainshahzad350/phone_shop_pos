import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('current behavior defaults reflect expected capability set', () {
      const flags = FeatureFlags.currentBehaviorDefaults();

      expect(flags.imeiStock, isTrue);
      expect(flags.qtyStock, isTrue);
      expect(flags.repairModule, isFalse);
      expect(flags.accessoriesModule, isFalse);
      expect(flags.dealerIssueModule, isFalse);
      expect(flags.reports, isTrue);
      expect(flags.navigationStyle, isFalse);
    });

    test('fromMap merges partial overrides with defaults', () {
      const defaults = FeatureFlags.currentBehaviorDefaults();

      final flags = FeatureFlags.fromMap(
        <String, Object?>{
          'repairModule': false,
          'reports': false,
        },
        defaults: defaults,
      );

      expect(flags.repairModule, isFalse);
      expect(flags.reports, isFalse);
      expect(flags.imeiStock, isTrue);
      expect(flags.qtyStock, isTrue);
    });

    test('fromMap ignores unknown and invalid values', () {
      const defaults = FeatureFlags.currentBehaviorDefaults();

      final flags = FeatureFlags.fromMap(
        <String, Object?>{
          'repairModule': 'false',
          'unknownFlag': false,
        },
        defaults: defaults,
      );

      expect(flags, defaults);
    });
  });
}
