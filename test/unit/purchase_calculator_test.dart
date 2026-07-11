import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_calculator.dart';

void main() {
  const calculator = PurchaseCalculator();

  PurchaseFormItem quantityItem({
    int quantity = 1,
    double unitCost = 0,
  }) =>
      PurchaseFormItem(
        productModelId: 'pm-qty',
        productName: 'Accessory',
        hasImei: false,
        quantity: quantity,
        unitCost: unitCost,
      );

  PurchaseFormItem imeiItem(List<double> costPrices) => PurchaseFormItem(
        productModelId: 'pm-imei',
        productName: 'Phone',
        hasImei: true,
        imeiEntries: <ImeiEntry>[
          for (var i = 0; i < costPrices.length; i++)
            ImeiEntry(imei1: 'imei-$i', costPrice: costPrices[i]),
        ],
      );

  group('PurchaseCalculator — subtotal', () {
    test('sums quantity * unitCost for non-IMEI items', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[
          quantityItem(quantity: 3, unitCost: 200),
          quantityItem(quantity: 2, unitCost: 50),
        ],
        discount: 0,
        tax: 0,
      );
      // 3*200 + 2*50 = 700
      expect(result.subtotal, closeTo(700, 0.0001));
      expect(result.total, closeTo(700, 0.0001));
    });

    test('sums IMEI entry cost prices for serialized items', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[
          imeiItem(<double>[45000, 55000]),
        ],
        discount: 0,
        tax: 0,
      );
      expect(result.subtotal, closeTo(100000, 0.0001));
      expect(result.total, closeTo(100000, 0.0001));
    });

    test('mixes IMEI and quantity items', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[
          imeiItem(<double>[30000]),
          quantityItem(quantity: 4, unitCost: 250),
        ],
        discount: 0,
        tax: 0,
      );
      // 30000 + 4*250 = 31000
      expect(result.subtotal, closeTo(31000, 0.0001));
    });

    test('empty item list yields zero subtotal and total', () {
      final result = calculator.calculate(
        items: const <PurchaseFormItem>[],
        discount: 500,
        tax: 100,
        // Discount clamps to subtotal (0); only tax remains.
      );
      expect(result.subtotal, closeTo(0, 0.0001));
      expect(result.total, closeTo(100, 0.0001));
    });
  });

  group('PurchaseCalculator — discount', () {
    test('discount reduces the total', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[quantityItem(quantity: 1, unitCost: 1000)],
        discount: 300,
        tax: 0,
      );
      expect(result.subtotal, closeTo(1000, 0.0001));
      expect(result.total, closeTo(700, 0.0001));
    });

    test('discount larger than subtotal is clamped so total never goes negative',
        () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[quantityItem(quantity: 1, unitCost: 1000)],
        discount: 5000,
        tax: 0,
      );
      expect(result.total, closeTo(0, 0.0001));
      expect(result.total, greaterThanOrEqualTo(0));
    });

    test('negative discount is treated as zero', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[quantityItem(quantity: 1, unitCost: 1000)],
        discount: -250,
        tax: 0,
      );
      expect(result.total, closeTo(1000, 0.0001));
    });
  });

  group('PurchaseCalculator — tax', () {
    test('tax is added on top of the discounted subtotal', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[quantityItem(quantity: 1, unitCost: 1000)],
        discount: 200,
        tax: 150,
      );
      // (1000 - 200) + 150 = 950
      expect(result.total, closeTo(950, 0.0001));
    });

    test('negative tax is treated as zero', () {
      final result = calculator.calculate(
        items: <PurchaseFormItem>[quantityItem(quantity: 1, unitCost: 1000)],
        discount: 0,
        tax: -75,
      );
      expect(result.total, closeTo(1000, 0.0001));
    });
  });

  test('total is never negative across a sweep of inputs', () {
    for (final discount in <double>[-100, 0, 500, 1000, 99999]) {
      for (final tax in <double>[-50, 0, 300]) {
        final result = calculator.calculate(
          items: <PurchaseFormItem>[quantityItem(quantity: 2, unitCost: 500)],
          discount: discount,
          tax: tax,
        );
        expect(
          result.total,
          greaterThanOrEqualTo(0),
          reason: 'total must stay >= 0 for discount=$discount tax=$tax',
        );
      }
    }
  });
}
