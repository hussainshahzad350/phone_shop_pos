import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/services/invoice_number_generator.dart';

void main() {
  const generator = InvoiceNumberGenerator();

  group('InvoiceNumberGenerator', () {
    test('formats date parts with zero-padding', () {
      final result = generator.generate(
        date: DateTime(2024, 1, 5),
        sequence: 1,
      );
      expect(result, 'INV-20240105-0001');
    });

    test('pads sequence to 4 digits', () {
      final result = generator.generate(
        date: DateTime(2024, 12, 31),
        sequence: 42,
      );
      expect(result, 'INV-20241231-0042');
    });

    test('handles sequence >= 10000 without truncation', () {
      final result = generator.generate(
        date: DateTime(2025, 6, 15),
        sequence: 10001,
      );
      // Sequence overflows 4-digit padding — that is acceptable; the format
      // just grows to accommodate the extra digits.
      expect(result, startsWith('INV-20250615-'));
      expect(result, contains('10001'));
    });

    test('produces unique values for consecutive sequences', () {
      final date = DateTime(2025, 1, 1);
      final results = List<String>.generate(
        100,
        (i) => generator.generate(date: date, sequence: i + 1),
      );
      expect(results.toSet().length, equals(results.length));
    });

    test('produces unique values across different dates', () {
      final dates = <DateTime>[
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 2),
        DateTime(2025, 12, 31),
      ];
      final results = dates
          .map((d) => generator.generate(date: d, sequence: 1))
          .toList(growable: false);
      expect(results.toSet().length, equals(dates.length));
    });
  });
}
