import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';

void main() {
  group('PHASE 1 / SECTION H (S-041 ... S-050)', () {
    test('S-041 Discount calculation preserves accuracy', () {
      const calculator = SalesCalculator();

      // Item: 10,000 × 2 = 20,000
      // Discount: 2,000
      // Total before tax: 18,000
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Phone A',
          hasImei: false,
          quantity: 2,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 2000,
        tax: 0,
        paidAmount: 18000,
      );

      expect(totals.subtotal, 20000);
      expect(totals.discount, 2000);
      expect(totals.total, 18000);
    });

    test('S-042 Tax applied after discount', () {
      const calculator = SalesCalculator();

      // Subtotal: 10,000
      // Discount: 1,000
      // Tax (on discounted): 900
      // Total: 9,900
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item A',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 1000,
        tax: 900,
        paidAmount: 9900,
      );

      expect(totals.subtotal, 10000);
      expect(totals.discount, 1000);
      expect(totals.tax, 900);
      expect(totals.total, 9900);
    });

    test('S-043 Multiple items subtotal summing', () {
      const calculator = SalesCalculator();

      // Item1: 5,000 × 1 = 5,000
      // Item2: 10,000 × 2 = 20,000
      // Subtotal: 25,000
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item A',
          hasImei: false,
          quantity: 1,
          unitPrice: 5000,
        ),
        const CartItemEntity(
          productModelId: 'prod_2',
          productName: 'Item B',
          hasImei: false,
          quantity: 2,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 25000,
      );

      expect(totals.subtotal, 25000);
      expect(totals.total, 25000);
    });

    test('S-044 Discount clamping (discount > subtotal)', () {
      const calculator = SalesCalculator();

      // Subtotal: 5,000
      // Requested discount: 10,000 (invalid)
      // Expected: discount clamped to 5,000
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 5000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 10000, // Too high
        tax: 0,
        paidAmount: 0,
      );

      expect(totals.subtotal, 5000);
      expect(totals.discount, 5000); // Clamped
      expect(totals.total, 0); // After discount
    });

    test('S-045 Negative discount clamped to zero', () {
      const calculator = SalesCalculator();

      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: -1000, // Negative (invalid)
        tax: 0,
        paidAmount: 10000,
      );

      expect(totals.discount, 0); // Clamped to 0
      expect(totals.subtotal, 10000);
      expect(totals.total, 10000);
    });

    test('S-046 Negative tax clamped to zero', () {
      const calculator = SalesCalculator();

      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: -500, // Negative (invalid)
        paidAmount: 10000,
      );

      expect(totals.tax, 0); // Clamped to 0
      expect(totals.total, 10000);
    });

    test('S-047 Overpayment clamped to total', () {
      const calculator = SalesCalculator();

      // Total: 10,000
      // Requested payment: 15,000 (overpayment)
      // Expected: clamped to 10,000
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 15000, // Too high
      );

      expect(totals.total, 10000);
      expect(totals.paidAmount, 10000); // Clamped
    });

    test('S-048 Partial payment tracked', () {
      const calculator = SalesCalculator();

      // Total: 50,000
      // Paid: 30,000
      // Remaining: 20,000
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Laptop',
          hasImei: false,
          quantity: 1,
          unitPrice: 50000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 30000,
      );

      expect(totals.total, 50000);
      expect(totals.paidAmount, 30000);
      expect(totals.remaining, 20000);
    });

    test('S-049 Complex: Discount + Tax + Partial Payment', () {
      const calculator = SalesCalculator();

      // Subtotal: 20,000
      // Discount: 2,000
      // Tax: 1,800
      // Total: 19,800
      // Paid: 15,000
      // Remaining: 4,800
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item',
          hasImei: false,
          quantity: 2,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 2000,
        tax: 1800,
        paidAmount: 15000,
      );

      expect(totals.subtotal, 20000);
      expect(totals.discount, 2000);
      expect(totals.tax, 1800);
      expect(totals.total, 19800);
      expect(totals.paidAmount, 15000);
      expect(totals.remaining, 4800);
    });

    test('S-050 Edge: Zero quantity items ignored', () {
      const calculator = SalesCalculator();

      // Items with 0 quantity are included but contribute 0 to total
      final items = <CartItemEntity>[
        const CartItemEntity(
          productModelId: 'prod_1',
          productName: 'Item A',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
        const CartItemEntity(
          productModelId: 'prod_2',
          productName: 'Item B (zero qty)',
          hasImei: false,
          quantity: 0,
          unitPrice: 5000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 10000,
      );

      expect(totals.subtotal, 10000); // Only item A counts
      expect(totals.total, 10000);
    });
  });
}
