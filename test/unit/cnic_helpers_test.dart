import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/utils/cnic_helpers.dart';

void main() {
  group('CnicHelpers.normalizeCnic', () {
    test('returns formatted string for bare 13 digits', () {
      expect(
        CnicHelpers.normalizeCnic('3520212345671'),
        '35202-1234567-1',
      );
    });

    test('strips dashes and formats correctly', () {
      expect(
        CnicHelpers.normalizeCnic('35202-1234567-1'),
        '35202-1234567-1',
      );
    });

    test('strips spaces and dashes mixed input', () {
      expect(
        CnicHelpers.normalizeCnic('35202 1234567 1'),
        '35202-1234567-1',
      );
    });

    test('returns null for fewer than 13 digits', () {
      expect(CnicHelpers.normalizeCnic('35202123456'), isNull);
    });

    test('returns null for more than 13 digits', () {
      expect(CnicHelpers.normalizeCnic('352021234567100'), isNull);
    });

    test('returns null for empty string', () {
      expect(CnicHelpers.normalizeCnic(''), isNull);
    });

    test('strips all non-digit characters before counting', () {
      // extra letters should cause digit count to fall short → null
      expect(CnicHelpers.normalizeCnic('XXXXX-XXXXXXX-X'), isNull);
    });
  });

  group('CnicHelpers.errorText', () {
    test('returns null for empty input (no error while blank)', () {
      expect(CnicHelpers.errorText(''), isNull);
    });

    test('returns null for whitespace-only input', () {
      expect(CnicHelpers.errorText('   '), isNull);
    });

    test('returns null for a valid formatted CNIC', () {
      expect(CnicHelpers.errorText('35202-1234567-1'), isNull);
    });

    test('returns null for valid raw 13 digits', () {
      expect(CnicHelpers.errorText('3520212345671'), isNull);
    });

    test('returns error string when digit count is 12', () {
      final result = CnicHelpers.errorText('352021234561');
      expect(result, isNotNull);
      expect(result, contains('13'));
    });

    test('returns error string when digit count is 14', () {
      final result = CnicHelpers.errorText('35202123456711');
      expect(result, isNotNull);
    });

    test('returns error string for non-digit-only short input', () {
      final result = CnicHelpers.errorText('abc123');
      expect(result, isNotNull);
    });
  });
}
