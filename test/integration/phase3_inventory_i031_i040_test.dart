import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/services/inventory_service.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';

void main() {
  group('PHASE 3 Inventory I-031..I-040', () {
    test('I-031 Large stock listing remains performant and capped', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
          serializedCount: 350, quantityCount: 350);

      final stopwatch = Stopwatch()..start();
      final rows =
          _expectSuccess(await context.inventoryService.getStockRows());
      stopwatch.stop();

      expect(rows.length, 200);
      expect(stopwatch.elapsedMilliseconds, lessThan(4000));
    });

    test('I-032 Custom listing limit is respected under load', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
          serializedCount: 300, quantityCount: 300);

      final rows = _expectSuccess(
        await context.inventoryService.getStockRows(limit: 350),
      );

      expect(rows.length, 350);
    });

    test('I-033 Search in large inventory is responsive and accurate',
        () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
          serializedCount: 250, quantityCount: 250);

      final stopwatch = Stopwatch()..start();
      final rows = _expectSuccess(
        await context.inventoryService
            .getStockRows(searchQuery: 'VIP-SEARCH-IMEI'),
      );
      stopwatch.stop();

      expect(rows, isNotEmpty);
      expect(
        rows.every((row) =>
            (row.imei1?.contains('VIP-SEARCH-IMEI') ?? false) ||
            row.productName.contains('VIP-SEARCH-IMEI') ||
            (row.sku?.contains('VIP-SEARCH-IMEI') ?? false)),
        isTrue,
      );
      expect(stopwatch.elapsedMilliseconds, lessThan(2500));
    });

    test('I-034 Low stock query returns only true low-stock items', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedQuantityInventoryWithLowStockPattern(total: 400);

      final lowRows =
          _expectSuccess(await context.inventoryService.getLowStockRows());

      expect(lowRows, isNotEmpty);
      expect(lowRows.every((row) => row.type == StockRowType.quantity), isTrue);
      expect(lowRows.every((row) => row.isLowStock), isTrue);
    });

    test('I-035 Inventory summary is consistent at scale', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
        serializedCount: 300,
        quantityCount: 300,
        soldEvery: 5,
      );

      final summary =
          _expectSuccess(await context.inventoryService.getInventorySummary());

      expect(summary.inStockPhones, 240);
      expect(summary.soldPhones, 60);
      expect(summary.totalAccessoryUnits, greaterThan(0));
      expect(summary.lowStockCount, greaterThanOrEqualTo(0));
    });

    test('I-036 Adjustment history paging stays deterministic', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i036_acc', 'I036 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i036',
        productModelId: 'prd_i036_acc',
        quantity: 1000,
        minQuantity: 20,
      );

      for (var i = 0; i < 120; i++) {
        _expectSuccess(
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i036_acc',
            delta: i.isEven ? 1 : -1,
            reason: 'correction',
          ),
        );
      }

      final page1 = _expectSuccess(
        await context.operationsService
            .getStockAdjustments(limit: 50, offset: 0),
      );
      final page2 = _expectSuccess(
        await context.operationsService
            .getStockAdjustments(limit: 50, offset: 50),
      );

      expect(page1.length, 50);
      expect(page2.length, 50);
      expect(page1.first.id == page2.first.id, isFalse);
    });

    test('I-037 Repeated refresh reads are stable and idempotent', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
          serializedCount: 180, quantityCount: 180);

      int? baselineLength;
      for (var i = 0; i < 15; i++) {
        final rows =
            _expectSuccess(await context.inventoryService.getStockRows());
        baselineLength ??= rows.length;
        expect(rows.length, baselineLength);
      }
    });

    test('I-038 Combined filters return only expected serialized items',
        () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.seedMixedInventory(
        serializedCount: 120,
        quantityCount: 120,
        soldEvery: 4,
      );

      final rows = _expectSuccess(
        await context.inventoryService.getStockRows(
          serializedStatusFilter: SerializedStockStatus.inStock,
          hasImeiFilter: true,
          limit: 300,
        ),
      );

      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.type == StockRowType.serialized), isTrue);
      expect(
        rows.every(
            (row) => row.serializedStatus == SerializedStockStatus.inStock),
        isTrue,
      );
    });

    test('I-039 Invalid adjustment does not create audit row', () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      final before = await context.countAdjustments();

      final result =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_missing_i039',
        delta: -4,
        reason: 'damage',
      );

      expect(result.isFailure, isTrue);
      final after = await context.countAdjustments();
      expect(after, before);
    });

    test('I-040 Zero-delta adjustment is rejected with no stock mutation',
        () async {
      final context = await _BatchDContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i040_acc', 'I040 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i040',
        productModelId: 'prd_i040_acc',
        quantity: 15,
        minQuantity: 5,
      );

      final beforeQty = await context.getInventoryQuantity('prd_i040_acc');
      final beforeAdjustments = await context.countAdjustments();

      final result =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_i040_acc',
        delta: 0,
        reason: 'correction',
      );

      expect(result.isFailure, isTrue);
      expect(await context.getInventoryQuantity('prd_i040_acc'), beforeQty);
      expect(await context.countAdjustments(), beforeAdjustments);
    });
  });
}

class _BatchDContext {
  _BatchDContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : inventoryRepository =
            SqliteInventoryRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase),
        inventoryService = InventoryService(
          repository: SqliteInventoryRepository(appDatabase: appDatabase),
        );

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteInventoryRepository inventoryRepository;
  final OperationsWorkflowService operationsService;
  final InventoryService inventoryService;

  static Future<_BatchDContext> createTemporary() async {
    final root =
        await Directory.systemTemp.createTemp('phone_shop_pos_phase3_i031_');
    final db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
    return _BatchDContext._(rootDirectory: root, appDatabase: db);
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }

  Future<void> seedMixedInventory({
    required int serializedCount,
    required int quantityCount,
    int soldEvery = 0,
  }) async {
    for (var i = 0; i < serializedCount; i++) {
      final productId = 'prd_ser_d_$i';
      final imei = i == 7
          ? 'VIP-SEARCH-IMEI-0007'
          : 'DIMEI${i.toString().padLeft(8, '0')}';
      final status =
          (soldEvery > 0 && i % soldEvery == 0) ? 'sold' : 'in_stock';

      await insertProduct(
        id: productId,
        name: i == 7 ? 'VIP-SEARCH-IMEI Phone' : 'D Serialized $i',
        hasImei: true,
        sku: 'D-SER-$i',
      );
      await insertSerializedStock(
        id: 'ser_d_$i',
        productModelId: productId,
        imei1: imei,
        status: status,
      );
    }

    for (var i = 0; i < quantityCount; i++) {
      final productId = 'prd_qty_d_$i';
      await insertProduct(
        id: productId,
        name: i == 5 ? 'VIP-SEARCH-IMEI Accessory' : 'D Quantity $i',
        hasImei: false,
        sku: i == 5 ? 'VIP-SEARCH-IMEI-SKU' : 'D-QTY-$i',
      );
      await insertInventoryStock(
        id: 'stk_d_$i',
        productModelId: productId,
        quantity: 10 + (i % 50),
        minQuantity: 5,
      );
    }
  }

  Future<void> seedQuantityInventoryWithLowStockPattern({
    required int total,
  }) async {
    for (var i = 0; i < total; i++) {
      final productId = 'prd_low_d_$i';
      await insertProduct(
        id: productId,
        name: 'D Low Pattern $i',
        hasImei: false,
        sku: 'D-LOW-$i',
      );
      await insertInventoryStock(
        id: 'stk_low_d_$i',
        productModelId: productId,
        quantity: i % 3 == 0 ? 2 : 20,
        minQuantity: 5,
      );
    }
  }

  Future<void> insertQuantityProduct(String id, String name) {
    return insertProduct(id: id, name: name, hasImei: false, sku: '$id-SKU');
  }

  Future<void> insertProduct({
    required String id,
    required String name,
    required bool hasImei,
    required String sku,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 9));
    await appDatabase.insert(TableNames.productModels, <String, Object?>{
      'id': id,
      'name': name,
      'sku': sku,
      'purchase_price': 5000,
      'sale_price': 6500,
      'has_imei': hasImei ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertSerializedStock({
    required String id,
    required String productModelId,
    required String imei1,
    String status = 'in_stock',
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 9, 0, 1));
    await appDatabase.insert(TableNames.serializedStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'imei1': imei1,
      'stock_status': status,
      'cost_price': 5000,
      'selling_price': 6500,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertInventoryStock({
    required String id,
    required String productModelId,
    required int quantity,
    required int minQuantity,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 9, 0, 2));
    await appDatabase.insert(TableNames.inventoryStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'unit_cost': 100,
      'unit_price': 150,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> countAdjustments() async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.stockAdjustments}',
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<int> getInventoryQuantity(String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    return (rows.single['quantity'] as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
