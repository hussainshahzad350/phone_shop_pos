import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_header_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/imei_picker_dialog.dart';

void main() {
  testWidgets('selects first IMEI on enter by default', (tester) async {
    final result = await _openDialogAndSelect(
      tester: tester,
      keySequence: const <LogicalKeyboardKey>[LogicalKeyboardKey.enter],
    );

    expect(result?.id, 'ss-1');
  });

  testWidgets('arrow down then enter selects next IMEI', (tester) async {
    final result = await _openDialogAndSelect(
      tester: tester,
      keySequence: const <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ],
    );

    expect(result?.id, 'ss-2');
  });

  testWidgets('shows error and retry when IMEI lookup fails', (tester) async {
    final repository = _FlakySalesRepository();
    SerializedStockEntity? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showDialog<SerializedStockEntity>(
                    context: context,
                    builder: (_) => ImeiPickerDialog(
                      productName: 'Phone A',
                      productModelId: 'pm-1',
                      repository: repository,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Temporary IMEI lookup failure'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('IMEI 1:'), findsWidgets);
    expect(selected, isNull);
  });
}

Future<SerializedStockEntity?> _openDialogAndSelect({
  required WidgetTester tester,
  required List<LogicalKeyboardKey> keySequence,
}) async {
  final repository = _FakeSalesRepository();
  SerializedStockEntity? selected;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showDialog<SerializedStockEntity>(
                    context: context,
                    builder: (_) => ImeiPickerDialog(
                      productName: 'Phone A',
                      productModelId: 'pm-1',
                      repository: repository,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  for (final key in keySequence) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  await tester.pumpAndSettle();
  return selected;
}

class _FakeSalesRepository implements SalesRepository {
  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    final all = <SerializedStockEntity>[
      _stock(id: 'ss-1', imei1: '111111111111111'),
      _stock(id: 'ss-2', imei1: '222222222222222'),
    ];
    final filtered = query.trim().isEmpty
        ? all
        : all
            .where((item) => item.imei1.contains(query.trim()))
            .toList(growable: false);
    return Success<List<SerializedStockEntity>>(filtered);
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) async {
    throw UnimplementedError();
  }

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
    return const Failure<SaleCompletionEntity>(
      AppError(code: 'not_implemented', message: 'Not used in this test'),
    );
  }

  @override
  Future<Result<SaleHeaderEntity>> getSaleById(String saleId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> voidSale({
    required String saleId,
    required String voidReason,
    String? voidedBy,
  }) =>
      throw UnimplementedError();
}

class _FlakySalesRepository extends _FakeSalesRepository {
  bool _hasFailed = false;

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    if (!_hasFailed) {
      _hasFailed = true;
      return const Failure<List<SerializedStockEntity>>(
        AppError(
          code: 'temporary_failure',
          message: 'Temporary IMEI lookup failure',
        ),
      );
    }
    return super.getAvailableImeis(productModelId, query: query, limit: limit);
  }
}

SerializedStockEntity _stock({
  required String id,
  required String imei1,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return SerializedStockEntity(
    id: id,
    productModelId: 'pm-1',
    imei1: imei1,
    stockStatus: SerializedStockStatus.inStock,
    costPrice: 1000,
    createdAt: now,
    updatedAt: now,
  );
}
