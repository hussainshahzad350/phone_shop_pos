import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/operations_history_query_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/sale_return_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

/// Edge-case coverage for SaleReturnService.processReturn. The phase-4 suite
/// exercises the happy path via OperationsWorkflowService; here we pin the
/// guard rails: reason/quantity validation, over-return rejection, and the
/// returnable-quantity accounting across successive partial returns.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;
  late String saleId;

  setUp(() async {
    ctx = await _Ctx.fresh();
    await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 100);
    // Sell 3 units, cash, fully paid (total 300).
    saleId = await ctx.sellQuantity(productId: 'acc-1', unitPrice: 100, qty: 3);
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test('rejects a blank reason', () async {
    final item = await ctx.firstItem(saleId);
    final result = await ctx.returns.processReturn(
      saleId: saleId,
      item: item,
      quantity: 1,
      reason: '   ',
    );
    expect(result.isFailure, isTrue);
  });

  test('rejects a non-positive quantity', () async {
    final item = await ctx.firstItem(saleId);
    final result = await ctx.returns.processReturn(
      saleId: saleId,
      item: item,
      quantity: 0,
      reason: 'defective',
    );
    expect(result.isFailure, isTrue);
  });

  test('rejects returning more than was sold', () async {
    final item = await ctx.firstItem(saleId);
    expect(item.returnableQty, 3);
    final result = await ctx.returns.processReturn(
      saleId: saleId,
      item: item,
      quantity: 5,
      reason: 'defective',
    );
    expect(result.isFailure, isTrue);
  });

  test('tracks returnable quantity across successive partial returns',
      () async {
    // First partial return of 2 of 3.
    _ok(await ctx.returns.processReturn(
      saleId: saleId,
      item: await ctx.firstItem(saleId),
      quantity: 2,
      reason: 'defective',
    ));

    final afterFirst = await ctx.firstItem(saleId);
    expect(afterFirst.returnedQty, 2);
    expect(afterFirst.returnableQty, 1);

    // A second return of 2 now exceeds the remaining 1 and must be rejected.
    final overRun = await ctx.returns.processReturn(
      saleId: saleId,
      item: afterFirst,
      quantity: 2,
      reason: 'defective',
    );
    expect(overRun.isFailure, isTrue);

    // Returning the final unit succeeds and exhausts the returnable quantity.
    _ok(await ctx.returns.processReturn(
      saleId: saleId,
      item: afterFirst,
      quantity: 1,
      reason: 'defective',
    ));
    final afterSecond = await ctx.firstItem(saleId);
    expect(afterSecond.returnableQty, 0);

    // All 3 sold units are back in inventory (started 5, sold 3, returned 3).
    expect(await ctx.stockQuantity('acc-1'), 5);
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        _sales = SqliteSalesRepository(appDatabase: db),
        history = OperationsHistoryQueryService(appDatabase: db),
        returns = SaleReturnService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository _sales;
  final OperationsHistoryQueryService history;
  final SaleReturnService returns;

  static Future<_Ctx> fresh() async {
    final dir =
        await Directory.systemTemp.createTemp('phone_shop_pos_sale_return_');
    final db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
    return _Ctx(dir: dir, db: db);
  }

  Future<void> dispose() async {
    await db.close();
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
  }

  Future<SalesInvoiceItemEntity> firstItem(String saleId) async {
    final detail = _ok(await history.getSalesInvoiceDetail(saleId));
    return detail!.items.first;
  }

  Future<int> stockQuantity(String productModelId) async {
    final rows = await db.database.query(
      TableNames.inventoryStock,
      columns: <String>['quantity'],
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    return (rows.first['quantity'] as num).toInt();
  }

  Future<void> setupAccessory({
    required String id,
    required int qty,
    required double cost,
    required double price,
  }) async {
    final now = DateTimeHelpers.nowUtc();
    _ok(
      await _products.createProduct(
        ProductEntity(
          id: id,
          name: 'Product $id',
          sku: 'SKU-$id',
          purchasePrice: cost,
          salePrice: price,
          hasImei: false,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    _ok(
      await _purchases.createPurchaseTransaction(
        items: <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: id,
            productName: 'Product $id',
            hasImei: false,
            quantity: qty,
            unitCost: cost,
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: cost * qty,
      ),
    );
  }

  Future<String> sellQuantity({
    required String productId,
    required double unitPrice,
    required int qty,
  }) async {
    final total = unitPrice * qty;
    final completion = _ok(
      await _sales.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productId,
            productName: 'Product $productId',
            hasImei: false,
            quantity: qty,
            unitPrice: unitPrice,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: total,
          discount: 0,
          tax: 0,
          total: total,
          paidAmount: total,
        ),
        customerId: null,
        paymentMethod: PaymentMethod.cash,
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }
}

T _ok<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.isFailure ? result.asFailure!.error.message : '',
  );
  return result.asSuccess!.value;
}
