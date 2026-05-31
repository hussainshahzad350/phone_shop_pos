import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

void main() {
  group('FormattingHelpers.parseLocaleDecimal', () {
    test('parses grouped PKR values without truncating thousands', () {
      expect(FormattingHelpers.parseLocaleDecimal('185,000.00'), 185000);
      expect(FormattingHelpers.parseLocaleDecimal('1,234,567'), 1234567);
    });

    test('still accepts decimal comma values', () {
      expect(FormattingHelpers.parseLocaleDecimal('185,50'), 185.50);
    });
  });
}
