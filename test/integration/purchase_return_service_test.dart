import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:phone_shop_pos/modules/reports/domain/services/purchase_return_service.dart';

/// Edge-case coverage for PurchaseReturnService.processPurchaseReturn: the
/// reason/quantity guards, over-return rejection, and returnable-quantity
/// accounting across successive partial returns (a purchase return removes the
/// returned units from inventory).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;
  late String purchaseId;

  setUp(() async {
    ctx = await _Ctx.fresh();
    await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);
    purchaseId = await ctx.firstPurchaseId();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test('rejects a blank reason', () async {
    final item = await ctx.firstItem(purchaseId);
    final result = await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: item,
      quantity: 1,
      reason: '  ',
    );
    expect(result.isFailure, isTrue);
  });

  test('rejects a non-positive quantity', () async {
    final item = await ctx.firstItem(purchaseId);
    final result = await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: item,
      quantity: 0,
      reason: 'defective',
    );
    expect(result.isFailure, isTrue);
  });

  test('rejects returning more than was purchased', () async {
    final item = await ctx.firstItem(purchaseId);
    expect(item.returnableQty, 5);
    final result = await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: item,
      quantity: 6,
      reason: 'defective',
    );
    expect(result.isFailure, isTrue);
  });

  test('tracks returnable quantity and removes returned units from inventory',
      () async {
    _ok(await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: await ctx.firstItem(purchaseId),
      quantity: 2,
      reason: 'defective',
    ));

    final afterFirst = await ctx.firstItem(purchaseId);
    expect(afterFirst.returnedQty, 2);
    expect(afterFirst.returnableQty, 3);
    // Two of the five received units left inventory.
    expect(await ctx.stockQuantity('acc-1'), 3);

    // A return of 4 now exceeds the remaining 3 and must be rejected.
    final overRun = await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: afterFirst,
      quantity: 4,
      reason: 'defective',
    );
    expect(overRun.isFailure, isTrue);

    // Returning the final 3 succeeds and empties both the returnable pool and
    // the remaining inventory.
    _ok(await ctx.returns.processPurchaseReturn(
      purchaseId: purchaseId,
      item: afterFirst,
      quantity: 3,
      reason: 'defective',
    ));
    final afterSecond = await ctx.firstItem(purchaseId);
    expect(afterSecond.returnableQty, 0);
    expect(await ctx.stockQuantity('acc-1'), 0);
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        history = OperationsHistoryQueryService(appDatabase: db),
        returns = PurchaseReturnService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final OperationsHistoryQueryService history;
  final PurchaseReturnService returns;

  static Future<_Ctx> fresh() async {
    final dir = await Directory.systemTemp
        .createTemp('phone_shop_pos_purchase_return_');
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

  Future<String> firstPurchaseId() async {
    final rows = _ok(await history.searchPurchaseHistory(
      supplierQuery: '',
      startDate: null,
      endDate: null,
    ));
    return rows.first.purchaseId;
  }

  Future<PurchaseHistoryItemEntity> firstItem(String purchaseId) async {
    final detail = _ok(await history.getPurchaseHistoryDetail(purchaseId));
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
}

T _ok<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.isFailure ? result.asFailure!.error.message : '',
  );
  return result.asSuccess!.value;
}
