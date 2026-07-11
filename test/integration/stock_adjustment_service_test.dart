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
import 'package:phone_shop_pos/modules/reports/domain/services/stock_adjustment_service.dart';

/// Behavioural coverage for the previously untested StockAdjustmentService:
/// quantity adjustments and their guards, and serialized-stock write-offs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;

  setUp(() async {
    ctx = await _Ctx.fresh();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  group('applyQuantityStockAdjustment', () {
    test('decreases and increases an existing stock quantity', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);

      final afterDecrease = _ok(await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: -2,
        reason: 'correction',
      ));
      expect(afterDecrease, 3);
      expect(await ctx.stockQuantity('acc-1'), 3);

      final afterIncrease = _ok(await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: 10,
        reason: 'miscounted',
      ));
      expect(afterIncrease, 13);
      expect(await ctx.stockQuantity('acc-1'), 13);
    });

    test('records an adjustment row with the correct type', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);
      _ok(await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: -1,
        reason: 'damage',
      ));

      final rows = await ctx.db.database.query(
        TableNames.stockAdjustments,
        where: 'product_model_id = ?',
        whereArgs: <Object?>['acc-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['adjustment_type'], 'decrease');
      expect((rows.first['quantity_delta'] as num).toInt(), -1);
    });

    test('rejects a zero delta', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);
      final result = await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: 0,
        reason: 'correction',
      );
      expect(result.isFailure, isTrue);
    });

    test('rejects an unknown reason', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);
      final result = await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: -1,
        reason: 'because',
      );
      expect(result.isFailure, isTrue);
    });

    test('refuses to drive stock below zero', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 100, price: 150);
      final result = await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: -100,
        reason: 'lost',
      );
      expect(result.isFailure, isTrue);
      // The rejected adjustment must not have mutated the quantity.
      expect(await ctx.stockQuantity('acc-1'), 5);
    });
  });

  group('writeOffSerializedStock', () {
    const imei = '111111111111111';

    test('marks an in-stock IMEI as damaged and logs the write-off', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      final stockId = await ctx.serializedStockId(imei);

      _ok(await ctx.adjustments.writeOffSerializedStock(
        serializedStockId: stockId,
        reason: 'broken',
      ));

      expect(await ctx.serializedStockStatus(stockId), 'damaged');
      final rows = await ctx.db.database.query(
        TableNames.stockAdjustments,
        where: 'serialized_stock_id = ?',
        whereArgs: <Object?>[stockId],
      );
      expect(rows, hasLength(1));
      expect(rows.first['adjustment_type'], 'write_off');
    });

    test('cannot write off the same IMEI twice', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      final stockId = await ctx.serializedStockId(imei);

      _ok(await ctx.adjustments.writeOffSerializedStock(
        serializedStockId: stockId,
        reason: 'broken',
      ));
      final second = await ctx.adjustments.writeOffSerializedStock(
        serializedStockId: stockId,
        reason: 'broken',
      );
      expect(second.isFailure, isTrue);
    });

    test('fails for an unknown serialized stock id', () async {
      final result = await ctx.adjustments.writeOffSerializedStock(
        serializedStockId: 'does-not-exist',
        reason: 'broken',
      );
      expect(result.isFailure, isTrue);
    });
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        adjustments = StockAdjustmentService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final StockAdjustmentService adjustments;

  static Future<_Ctx> fresh() async {
    final dir = await Directory.systemTemp
        .createTemp('phone_shop_pos_stock_adjustment_');
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

  Future<String> serializedStockId(String imei) async {
    final rows = await db.database.query(
      TableNames.serializedStock,
      columns: <String>['id'],
      where: 'imei1 = ?',
      whereArgs: <Object?>[imei],
      limit: 1,
    );
    return rows.first['id'] as String;
  }

  Future<String?> serializedStockStatus(String stockId) async {
    final rows = await db.database.query(
      TableNames.serializedStock,
      columns: <String>['stock_status'],
      where: 'id = ?',
      whereArgs: <Object?>[stockId],
      limit: 1,
    );
    return rows.first['stock_status'] as String?;
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

  Future<void> setupPhone({
    required String id,
    required String imei,
    required double cost,
    required double price,
  }) async {
    final now = DateTimeHelpers.nowUtc();
    _ok(
      await _products.createProduct(
        ProductEntity(
          id: id,
          name: 'Phone $id',
          sku: 'SKU-$id',
          purchasePrice: cost,
          salePrice: price,
          hasImei: true,
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
            productName: 'Phone $id',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: imei, costPrice: cost),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: cost,
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
