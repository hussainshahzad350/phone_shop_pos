import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_service.dart';

void main() {
  group('PHASE 1 / SECTION A-B (S-001 ... S-010)', () {
    test('S-001 Simple phone sale (full payment)', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{},
        availableSerializedStockIds: <String>{'ser_phone_1'},
        costByProductId: <String, double>{'prd_phone_1': 90000},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 100000,
        discount: 0,
        tax: 0,
        total: 100000,
        paidAmount: 100000,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_phone_1',
          productName: 'Phone A',
          hasImei: true,
          quantity: 1,
          unitPrice: 100000,
          serializedStockId: 'ser_phone_1',
          imei: '356789101234501',
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess?.value.invoiceNumber, startsWith('INV-'));
      expect(result.asSuccess?.value.totals.remaining, 0);
      final imeiAvailabilityAfterSale =
          await repository.isImeiAvailable('ser_phone_1');
      expect(imeiAvailabilityAfterSale.isSuccess, isTrue);
      expect(imeiAvailabilityAfterSale.asSuccess?.value, isFalse);
      expect(repository.completedSales.length, 1);
      expect(repository.dashboardSalesToday, 100000);
    });

    test('S-002 Accessory sale (quantity item)', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_case_1': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_case_1': 600},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 1600,
        discount: 0,
        tax: 0,
        total: 1600,
        paidAmount: 1600,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_case_1',
          productName: 'Case',
          hasImei: false,
          quantity: 2,
          unitPrice: 800,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      final remainingQty = await repository.getAvailableQuantity('prd_case_1');
      expect(remainingQty.isSuccess, isTrue);
      expect(remainingQty.asSuccess?.value, 8);
      expect(result.asSuccess?.value.totals.total, 1600);
      expect(repository.completedSales.first.calculatedProfit, 400);
      expect(items.first.serializedStockId, isNull);
    });

    test('S-003 Mixed cart (phone + accessory)', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_charger_1': 9},
        availableSerializedStockIds: <String>{'ser_phone_2'},
        costByProductId: <String, double>{
          'prd_phone_2': 70000,
          'prd_charger_1': 700,
        },
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_phone_2',
          productName: 'Phone B',
          hasImei: true,
          quantity: 1,
          unitPrice: 80000,
          serializedStockId: 'ser_phone_2',
          imei: '356789101234502',
        ),
        CartItemEntity(
          productModelId: 'prd_charger_1',
          productName: 'Charger',
          hasImei: false,
          quantity: 2,
          unitPrice: 1000,
        ),
      ];
      const totals = SaleTotalsEntity(
        subtotal: 82000,
        discount: 0,
        tax: 0,
        total: 82000,
        paidAmount: 82000,
      );

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(repository.completedSales.length, 1);
      final phoneAvailability = await repository.isImeiAvailable('ser_phone_2');
      expect(phoneAvailability.isSuccess, isTrue);
      expect(phoneAvailability.asSuccess?.value, isFalse);
      final chargerQty = await repository.getAvailableQuantity('prd_charger_1');
      expect(chargerQty.isSuccess, isTrue);
      expect(chargerQty.asSuccess?.value, 7);
      expect(result.asSuccess?.value.totals.total, 82000);
    });

    test('S-004 Multi-item accessory sale', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{
          'prd_case_2': 20,
          'prd_cable_2': 20,
          'prd_guard_2': 20,
        },
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{
          'prd_case_2': 400,
          'prd_cable_2': 300,
          'prd_guard_2': 250,
        },
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_case_2',
          productName: 'Case',
          hasImei: false,
          quantity: 2,
          unitPrice: 700,
        ),
        CartItemEntity(
          productModelId: 'prd_cable_2',
          productName: 'Cable',
          hasImei: false,
          quantity: 3,
          unitPrice: 500,
        ),
        CartItemEntity(
          productModelId: 'prd_guard_2',
          productName: 'Screen Guard',
          hasImei: false,
          quantity: 1,
          unitPrice: 600,
        ),
      ];
      const totals = SaleTotalsEntity(
        subtotal: 3500,
        discount: 0,
        tax: 0,
        total: 3500,
        paidAmount: 3500,
      );

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(items.fold<double>(0, (sum, item) => sum + item.lineTotal), 3500);
      expect(repository.completedSales.single.items.length, 3);
      expect(
        repository.completedSales.single.items
            .map((item) => item.productModelId)
            .toSet()
            .length,
        3,
      );
    });

    test('S-005 Multi-phone invoice', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{},
        availableSerializedStockIds: <String>{'ser_phone_5a', 'ser_phone_5b'},
        costByProductId: <String, double>{
          'prd_phone_5a': 50000,
          'prd_phone_5b': 60000,
        },
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_phone_5a',
          productName: 'Phone 5A',
          hasImei: true,
          quantity: 1,
          unitPrice: 65000,
          serializedStockId: 'ser_phone_5a',
          imei: '356789101234503',
        ),
        CartItemEntity(
          productModelId: 'prd_phone_5b',
          productName: 'Phone 5B',
          hasImei: true,
          quantity: 1,
          unitPrice: 78000,
          serializedStockId: 'ser_phone_5b',
          imei: '356789101234504',
        ),
      ];
      const totals = SaleTotalsEntity(
        subtotal: 143000,
        discount: 0,
        tax: 0,
        total: 143000,
        paidAmount: 143000,
      );

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      final firstImeiAvailability =
          await repository.isImeiAvailable('ser_phone_5a');
      final secondImeiAvailability =
          await repository.isImeiAvailable('ser_phone_5b');
      expect(firstImeiAvailability.isSuccess, isTrue);
      expect(firstImeiAvailability.asSuccess?.value, isFalse);
      expect(secondImeiAvailability.isSuccess, isTrue);
      expect(secondImeiAvailability.asSuccess?.value, isFalse);
      expect(repository.completedSales.length, 1);
      expect(repository.dashboardSalesToday, 143000);
    });

    test('S-006 Partial payment (registered customer)', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_6': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_6': 15000},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 50000,
        discount: 0,
        tax: 0,
        total: 50000,
        paidAmount: 20000,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_6',
          productName: 'Accessory 6',
          hasImei: false,
          quantity: 1,
          unitPrice: 50000,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        customerId: 'cus_registered_6',
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess?.value.totals.remaining, 30000);
      expect(repository.receivableAmount, 30000);
    });

    test('S-007 Zero payment sale (credit sale)', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_7': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_7': 1000},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 1200,
        discount: 0,
        tax: 0,
        total: 1200,
        paidAmount: 0,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_7',
          productName: 'Accessory 7',
          hasImei: false,
          quantity: 1,
          unitPrice: 1200,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        customerId: 'cus_registered_7',
        paymentMethod: 'credit',
      );

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess?.value.totals.remaining, 1200);
      expect(repository.receivableAmount, 1200);
    });

    test('Credit sale blocks walk-in customer', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_7b': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_7b': 1000},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 1200,
        discount: 0,
        tax: 0,
        total: 1200,
        paidAmount: 0,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_7b',
          productName: 'Accessory 7B',
          hasImei: false,
          quantity: 1,
          unitPrice: 1200,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'credit',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.asFailure?.error.code,
        'registered_customer_required_for_credit_sale',
      );
    });

    test('Walk-in customer cannot keep pending balance', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_walkin': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_walkin': 800},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 1000,
        discount: 0,
        tax: 0,
        total: 1000,
        paidAmount: 0,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_walkin',
          productName: 'Walk-in Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 1000,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        customerId: null,
        paymentMethod: 'cash',
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'walk_in_requires_full_payment');
    });

    test('Credit method rejects upfront paid amount', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_credit_paid': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_credit_paid': 600},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 1500,
        discount: 0,
        tax: 0,
        total: 1500,
        paidAmount: 500,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_credit_paid',
          productName: 'Credit Paid Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 1500,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        customerId: 'cus_registered_credit_paid',
        paymentMethod: 'credit',
      );

      expect(result.isFailure, isTrue);
      expect(
          result.asFailure?.error.code, 'credit_method_requires_zero_upfront');
    });

    test('Registered customer allows partial upfront with cash method',
        () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_partial_cash': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_partial_cash': 700},
      );
      final service = SalesService(repository: repository);

      const totals = SaleTotalsEntity(
        subtotal: 2000,
        discount: 0,
        tax: 0,
        total: 2000,
        paidAmount: 1200,
      );
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_partial_cash',
          productName: 'Partial Cash Item',
          hasImei: false,
          quantity: 1,
          unitPrice: 2000,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: totals,
        customerId: 'cus_registered_partial',
        paymentMethod: 'cash',
      );

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess?.value.totals.remaining, 800);
    });

    test('S-008 Exact payment', () {
      const calculator = SalesCalculator();
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_8',
          productName: 'Accessory 8',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 10000,
      );

      expect(totals.remaining, 0);
    });

    test('S-009 Overpayment attempt', () {
      const calculator = SalesCalculator();
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_9',
          productName: 'Accessory 9',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 15000,
      );

      expect(totals.total, 10000);
      expect(totals.paidAmount, 10000);
      expect(totals.remaining, 0);
    });

    test('S-010 Negative paid amount', () {
      const calculator = SalesCalculator();
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_10',
          productName: 'Accessory 10',
          hasImei: false,
          quantity: 1,
          unitPrice: 10000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: -500,
      );

      expect(totals.paidAmount, 0);
      expect(totals.remaining, 10000);
    });

    test('S-011 Decimal payment', () {
      const calculator = SalesCalculator();
      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_11',
          productName: 'Accessory 11',
          hasImei: false,
          quantity: 1,
          unitPrice: 5000,
        ),
      ];

      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 1000.50,
      );

      expect(totals.paidAmount, closeTo(1000.50, 0.0001));
      expect(totals.remaining, closeTo(3999.50, 0.0001));
    });

    test('S-012 Sell out-of-stock accessory', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_12': 0},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_12': 700},
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_12',
          productName: 'Accessory 12',
          hasImei: false,
          quantity: 1,
          unitPrice: 1000,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: const SaleTotalsEntity(
          subtotal: 1000,
          discount: 0,
          tax: 0,
          total: 1000,
          paidAmount: 1000,
        ),
        paymentMethod: 'cash',
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'insufficient_stock');
      expect(repository.completedSales, isEmpty);
    });

    test('S-013 Sell qty above stock', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_13': 3},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_13': 500},
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_13',
          productName: 'Accessory 13',
          hasImei: false,
          quantity: 5,
          unitPrice: 900,
        ),
      ];

      final result = await service.completeSale(
        items: items,
        totals: const SaleTotalsEntity(
          subtotal: 4500,
          discount: 0,
          tax: 0,
          total: 4500,
          paidAmount: 4500,
        ),
        paymentMethod: 'cash',
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'insufficient_stock');
      expect(repository.completedSales, isEmpty);
    });

    test('S-014 Duplicate IMEI sale attempt', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{},
        availableSerializedStockIds: <String>{'ser_phone_14'},
        costByProductId: <String, double>{'prd_phone_14': 50000},
      );
      final service = SalesService(repository: repository);

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_phone_14',
          productName: 'Phone 14',
          hasImei: true,
          quantity: 1,
          unitPrice: 60000,
          serializedStockId: 'ser_phone_14',
          imei: '356789101234514',
        ),
      ];
      const totals = SaleTotalsEntity(
        subtotal: 60000,
        discount: 0,
        tax: 0,
        total: 60000,
        paidAmount: 60000,
      );

      final first = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );
      final second = await service.completeSale(
        items: items,
        totals: totals,
        paymentMethod: 'cash',
      );

      expect(first.isSuccess, isTrue);
      expect(second.isFailure, isTrue);
      expect(second.asFailure?.error.code, 'imei_unavailable');
      expect(repository.completedSales.length, 1);
    });

    test('S-015 Add same IMEI twice in same cart', () {
      final service = SalesService(
        repository: _InMemorySalesRepository(
          quantityByProductId: <String, int>{},
          availableSerializedStockIds: <String>{'ser_phone_15'},
          costByProductId: <String, double>{'prd_phone_15': 40000},
        ),
      );

      final product = ProductEntity(
        id: 'prd_phone_15',
        name: 'Phone 15',
        purchasePrice: 40000,
        salePrice: 50000,
        hasImei: true,
        isActive: true,
        createdAt: DateTime.utc(2026, 5, 17),
        updatedAt: DateTime.utc(2026, 5, 17),
      );

      final firstAdd = service.addToCart(
        items: const <CartItemEntity>[],
        product: product,
        serializedStockId: 'ser_phone_15',
        imei: '356789101234515',
      );
      expect(firstAdd.isSuccess, isTrue);

      final duplicateAdd = service.addToCart(
        items: firstAdd.asSuccess!.value,
        product: product,
        serializedStockId: 'ser_phone_15',
        imei: '356789101234515',
      );

      expect(duplicateAdd.isFailure, isTrue);
      expect(duplicateAdd.asFailure?.error.code, 'duplicate_imei');
    });

    test('S-016 Remove item before completion', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_16': 10},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_16': 200},
      );
      final service = SalesService(repository: repository);

      final product = ProductEntity(
        id: 'prd_acc_16',
        name: 'Accessory 16',
        purchasePrice: 200,
        salePrice: 400,
        hasImei: false,
        isActive: true,
        createdAt: DateTime.utc(2026, 5, 17),
        updatedAt: DateTime.utc(2026, 5, 17),
      );

      final addResult = service.addToCart(
        items: const <CartItemEntity>[],
        product: product,
        quantity: 2,
      );
      expect(addResult.isSuccess, isTrue);

      final removeResult = service.removeFromCart(
        items: addResult.asSuccess!.value,
        index: 0,
      );

      expect(removeResult.isSuccess, isTrue);
      expect(removeResult.asSuccess?.value, isEmpty);

      final qtyAfterRemove =
          await repository.getAvailableQuantity('prd_acc_16');
      expect(qtyAfterRemove.isSuccess, isTrue);
      expect(qtyAfterRemove.asSuccess?.value, 10);
      expect(repository.completedSales, isEmpty);
    });

    test('S-017 Cancel entire sale', () async {
      final repository = _InMemorySalesRepository(
        quantityByProductId: <String, int>{'prd_acc_17': 8},
        availableSerializedStockIds: <String>{},
        costByProductId: <String, double>{'prd_acc_17': 300},
      );
      final service = SalesService(repository: repository);

      final product = ProductEntity(
        id: 'prd_acc_17',
        name: 'Accessory 17',
        purchasePrice: 300,
        salePrice: 500,
        hasImei: false,
        isActive: true,
        createdAt: DateTime.utc(2026, 5, 17),
        updatedAt: DateTime.utc(2026, 5, 17),
      );

      final addResult = service.addToCart(
        items: const <CartItemEntity>[],
        product: product,
        quantity: 2,
      );
      expect(addResult.isSuccess, isTrue);

      // Cancel simulated by abandoning cart without calling completeSale.
      final qtyAfterCancel =
          await repository.getAvailableQuantity('prd_acc_17');
      expect(qtyAfterCancel.isSuccess, isTrue);
      expect(qtyAfterCancel.asSuccess?.value, 8);
      expect(repository.completedSales, isEmpty);
    });

    test('S-018 Quantity change updates total', () {
      final service = SalesService(
        repository: _InMemorySalesRepository(
          quantityByProductId: <String, int>{'prd_acc_18': 20},
          availableSerializedStockIds: <String>{},
          costByProductId: <String, double>{'prd_acc_18': 100},
        ),
      );
      const calculator = SalesCalculator();

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_18',
          productName: 'Accessory 18',
          hasImei: false,
          quantity: 1,
          unitPrice: 1200,
        ),
      ];

      final initialTotals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      final updateResult = service.updateQty(
        items: items,
        index: 0,
        quantity: 3,
      );
      expect(updateResult.isSuccess, isTrue);

      final updatedItems = updateResult.asSuccess!.value;
      final updatedTotals = calculator.calculate(
        items: updatedItems,
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      expect(initialTotals.total, 1200);
      expect(updatedTotals.total, 3600);
    });

    test('S-019 Remove cart line', () {
      final service = SalesService(
        repository: _InMemorySalesRepository(
          quantityByProductId: <String, int>{
            'prd_acc_19a': 10,
            'prd_acc_19b': 10
          },
          availableSerializedStockIds: <String>{},
          costByProductId: <String, double>{
            'prd_acc_19a': 100,
            'prd_acc_19b': 100,
          },
        ),
      );
      const calculator = SalesCalculator();

      const items = <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_acc_19a',
          productName: 'Accessory 19A',
          hasImei: false,
          quantity: 1,
          unitPrice: 1000,
        ),
        CartItemEntity(
          productModelId: 'prd_acc_19b',
          productName: 'Accessory 19B',
          hasImei: false,
          quantity: 1,
          unitPrice: 2000,
        ),
      ];

      final before = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      final removeResult = service.removeFromCart(items: items, index: 0);
      expect(removeResult.isSuccess, isTrue);

      final after = calculator.calculate(
        items: removeResult.asSuccess!.value,
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      expect(before.total, 3000);
      expect(after.total, 2000);
    });

    test('S-020 Empty cart sale attempt', () async {
      final service = SalesService(
        repository: _InMemorySalesRepository(
          quantityByProductId: <String, int>{},
          availableSerializedStockIds: <String>{},
          costByProductId: <String, double>{},
        ),
      );

      final result = await service.completeSale(
        items: const <CartItemEntity>[],
        totals: const SaleTotalsEntity(
          subtotal: 0,
          discount: 0,
          tax: 0,
          total: 0,
          paidAmount: 0,
        ),
        paymentMethod: 'cash',
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'empty_cart');
    });
  });
}

class _InMemorySalesRepository implements SalesRepository {
  _InMemorySalesRepository({
    required Map<String, int> quantityByProductId,
    required Set<String> availableSerializedStockIds,
    required Map<String, double> costByProductId,
  })  : _quantityByProductId = Map<String, int>.from(quantityByProductId),
        _availableSerializedStockIds =
            Set<String>.from(availableSerializedStockIds),
        _costByProductId = Map<String, double>.from(costByProductId);

  final Map<String, int> _quantityByProductId;
  final Set<String> _availableSerializedStockIds;
  final Map<String, double> _costByProductId;

  int _invoiceCounter = 1;
  final List<_RecordedSale> completedSales = <_RecordedSale>[];

  double get dashboardSalesToday => completedSales.fold<double>(
        0,
        (sum, sale) => sum + sale.completion.totals.total,
      );

  double get receivableAmount => completedSales.fold<double>(
        0,
        (sum, sale) => sum + sale.completion.totals.remaining,
      );

  @override
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) async {
    if (paymentMethod == null || paymentMethod.isEmpty) {
      return const Failure<SaleCompletionEntity>(
        AppError(
            code: 'payment_method_required',
            message: 'Payment method required'),
      );
    }

    for (final item in items) {
      if (item.hasImei) {
        final stockId = item.serializedStockId;
        if (stockId == null ||
            !_availableSerializedStockIds.contains(stockId)) {
          return const Failure<SaleCompletionEntity>(
            AppError(code: 'imei_unavailable', message: 'IMEI unavailable'),
          );
        }
      } else {
        final available = _quantityByProductId[item.productModelId] ?? 0;
        if (available < item.quantity) {
          return const Failure<SaleCompletionEntity>(
            AppError(code: 'insufficient_stock', message: 'Insufficient stock'),
          );
        }
      }
    }

    for (final item in items) {
      if (item.hasImei) {
        _availableSerializedStockIds.remove(item.serializedStockId);
      } else {
        _quantityByProductId[item.productModelId] =
            (_quantityByProductId[item.productModelId] ?? 0) - item.quantity;
      }
    }

    final completion = SaleCompletionEntity(
      saleId: 'sale_${completedSales.length + 1}',
      invoiceNumber: 'INV-${_invoiceCounter++}',
      totals: totals,
    );

    var calculatedProfit = 0.0;
    for (final item in items) {
      final unitCost = _costByProductId[item.productModelId] ?? 0;
      calculatedProfit += (item.unitPrice - unitCost) * item.quantity;
    }

    completedSales.add(
      _RecordedSale(
        completion: completion,
        items: items,
        calculatedProfit: calculatedProfit,
      ),
    );

    return Success<SaleCompletionEntity>(completion);
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    return Success<int>(_quantityByProductId[productModelId] ?? 0);
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    return const Success<List<SerializedStockEntity>>(
        <SerializedStockEntity>[]);
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    return Success<bool>(
        _availableSerializedStockIds.contains(serializedStockId));
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<CustomerOptionEntity>>(<CustomerOptionEntity>[]);
  }

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<ProductEntity>>(<ProductEntity>[]);
  }

  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async {
    try {
      final value = await action();
      return Success<T>(value);
    } catch (error) {
      return Failure<T>(
        AppError(
          code: 'in_memory_repository_error',
          message: 'In-memory repository failed during $operation',
          details: error,
        ),
      );
    }
  }
}

class _RecordedSale {
  const _RecordedSale({
    required this.completion,
    required this.items,
    required this.calculatedProfit,
  });

  final SaleCompletionEntity completion;
  final List<CartItemEntity> items;
  final double calculatedProfit;
}
