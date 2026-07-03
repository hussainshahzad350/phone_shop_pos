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

  group('FormattingHelpers.decimal', () {
    test('drops trailing zeros so whole amounts show without paisa', () {
      expect(FormattingHelpers.decimal(100), '100');
      expect(FormattingHelpers.decimal(100.00), '100');
      expect(FormattingHelpers.decimal(0), '0');
      expect(FormattingHelpers.decimal(1000), '1,000');
    });

    test('keeps meaningful fractional digits and trims trailing zeros', () {
      expect(FormattingHelpers.decimal(100.5), '100.5');
      expect(FormattingHelpers.decimal(100.50), '100.5');
      expect(FormattingHelpers.decimal(100.55), '100.55');
    });

    test('currencyPkr follows the same trimmed display', () {
      expect(FormattingHelpers.currencyPkr(105000), 'PKR 105,000');
      expect(FormattingHelpers.currencyPkr(1250.5), 'PKR 1,250.5');
    });

    test('trimTrailingZeros: false preserves fixed decimals when needed', () {
      expect(
        FormattingHelpers.decimal(100, trimTrailingZeros: false),
        '100.00',
      );
    });
  });
}
