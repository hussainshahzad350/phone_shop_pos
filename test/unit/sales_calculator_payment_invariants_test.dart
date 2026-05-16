import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';

void main() {
  const calculator = SalesCalculator();

  const items = <CartItemEntity>[
    CartItemEntity(
      productModelId: 'pm-1',
      productName: 'Phone A',
      hasImei: false,
      quantity: 1,
      unitPrice: 5000,
    ),
  ];

  group('SalesCalculator — paid_amount invariant', () {
    test('paid_amount equal to total is accepted unchanged', () {
      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 5000,
      );
      expect(totals.paidAmount, closeTo(5000, 0.0001));
    });

    test('paid_amount below total is accepted unchanged', () {
      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 3000,
      );
      expect(totals.paidAmount, closeTo(3000, 0.0001));
    });

    test('paid_amount exceeding total is clamped to total', () {
      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 9999,
      );
      expect(totals.total, closeTo(5000, 0.0001));
      expect(totals.paidAmount, closeTo(5000, 0.0001));
    });

    test('negative paid_amount is clamped to zero', () {
      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: -100,
      );
      expect(totals.paidAmount, closeTo(0, 0.0001));
    });

    test('remaining is always non-negative', () {
      for (final paid in <double>[-500, 0, 2500, 5000, 9999]) {
        final totals = calculator.calculate(
          items: items,
          discount: 0,
          tax: 0,
          paidAmount: paid,
        );
        expect(
          totals.remaining,
          greaterThanOrEqualTo(0),
          reason: 'remaining must be >= 0 for paid=$paid',
        );
      }
    });

    test('paid_amount is zero when cart is empty', () {
      final totals = calculator.calculate(
        items: const <CartItemEntity>[],
        discount: 0,
        tax: 0,
        paidAmount: 500,
      );
      // total = 0 for empty cart; paidAmount clamped to 0
      expect(totals.total, closeTo(0, 0.0001));
      expect(totals.paidAmount, closeTo(0, 0.0001));
    });

    test('paid_amount is clamped after discount reduces total', () {
      // total = 5000 - 2000 = 3000; paidAmount = 4000 must clamp to 3000
      final totals = calculator.calculate(
        items: items,
        discount: 2000,
        tax: 0,
        paidAmount: 4000,
      );
      expect(totals.total, closeTo(3000, 0.0001));
      expect(totals.paidAmount, closeTo(3000, 0.0001));
    });
  });
}
