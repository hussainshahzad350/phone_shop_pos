import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';

void main() {
  group('PHASE 3 Inventory I-011..I-020', () {
    test(
        'I-011 Increase stock adjustment (+5 correction) updates stock and logs audit',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i011_acc',
        name: 'I011 Accessory',
        sku: 'I011-ACC',
        purchasePrice: 100,
        salePrice: 140,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i011_acc',
        productName: 'I011 Accessory',
        quantity: 3,
        unitCost: 100,
      );

      final before = await context.getAccessoryQuantity('prd_i011_acc');
      final newQty = _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i011_acc',
          delta: 5,
          reason: 'correction',
          notes: 'manual recount',
        ),
      );

      expect(before, 3);
      expect(newQty, 8);
      expect(await context.getAccessoryQuantity('prd_i011_acc'), 8);

      final latest = await context.latestStockAdjustment();
      expect(latest['product_model_id'], 'prd_i011_acc');
      expect(latest['adjustment_type'], 'increase');
      expect(latest['quantity_delta'], 5);
      expect(latest['reason'], 'correction');
    });

    test(
        'I-012 Decrease stock adjustment subtracts quantity and never below zero',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i012_acc',
        name: 'I012 Accessory',
        sku: 'I012-ACC',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i012_acc',
        productName: 'I012 Accessory',
        quantity: 10,
        unitCost: 100,
      );

      final afterDecrease = _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i012_acc',
          delta: -4,
          reason: 'damage',
        ),
      );
      expect(afterDecrease, 6);

      final blocked =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_i012_acc',
        delta: -7,
        reason: 'damage',
      );
      expect(blocked.isFailure, isTrue);
      expect(await context.getAccessoryQuantity('prd_i012_acc'), 6);
    });

    test('I-013 Write-off IMEI phone removes availability and records audit',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i013_phone',
        name: 'I013 Phone',
        sku: 'I013-PHONE',
        purchasePrice: 50000,
        salePrice: 55000,
        hasImei: true,
      );
      await context.purchasePhone(
        productModelId: 'prd_i013_phone',
        productName: 'I013 Phone',
        imei1: '356789101234611',
        costPrice: 50000,
      );

      final serializedId =
          await context.getSerializedStockIdByImei('356789101234611');
      _expectSuccess(
        await context.operationsService.writeOffSerializedStock(
          serializedStockId: serializedId,
          reason: 'theft',
          notes: 'missing from shelf',
        ),
      );

      final row = await context.getSerializedById(serializedId);
      expect(row['stock_status'], 'damaged');

      final available = _expectSuccess(
        await context.salesRepository.getAvailableImeis('prd_i013_phone'),
      );
      expect(available.where((item) => item.id == serializedId), isEmpty);

      final latest = await context.latestStockAdjustment();
      expect(latest['adjustment_type'], 'write_off');
      expect(latest['serialized_stock_id'], serializedId);
      expect(latest['quantity_delta'], -1);
      expect(latest['reason'], 'theft');
    });

    test('I-014 Prevent adjustment that would push stock below zero', () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i014_acc',
        name: 'I014 Accessory',
        sku: 'I014-ACC',
        purchasePrice: 90,
        salePrice: 130,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i014_acc',
        productName: 'I014 Accessory',
        quantity: 2,
        unitCost: 90,
      );

      final result =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_i014_acc',
        delta: -3,
        reason: 'damage',
      );

      expect(result.isFailure, isTrue);
      expect(await context.getAccessoryQuantity('prd_i014_acc'), 2);
      expect(await context.countStockAdjustments(), 0);
    });

    test('I-015 Adjustment without reason is rejected (mandatory reason)',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i015_acc',
        name: 'I015 Accessory',
        sku: 'I015-ACC',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i015_acc',
        productName: 'I015 Accessory',
        quantity: 5,
        unitCost: 100,
      );

      final result =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_i015_acc',
        delta: 1,
        reason: '   ',
      );

      expect(result.isFailure, isTrue);
      expect(await context.getAccessoryQuantity('prd_i015_acc'), 5);
      expect(await context.countStockAdjustments(), 0);
    });

    test('I-016 Large adjustment values are handled safely', () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i016_acc',
        name: 'I016 Accessory',
        sku: 'I016-ACC',
        purchasePrice: 80,
        salePrice: 120,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i016_acc',
        productName: 'I016 Accessory',
        quantity: 600,
        unitCost: 80,
      );

      final plus = _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i016_acc',
          delta: 1000,
          reason: 'correction',
        ),
      );
      expect(plus, 1600);

      final minus = _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i016_acc',
          delta: -1000,
          reason: 'damage',
        ),
      );
      expect(minus, 600);
      expect(await context.getAccessoryQuantity('prd_i016_acc'), 600);
    });

    test('I-017 Adjustment record is created in stock_adjustments', () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i017_acc',
        name: 'I017 Accessory',
        sku: 'I017-ACC',
        purchasePrice: 100,
        salePrice: 140,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i017_acc',
        productName: 'I017 Accessory',
        quantity: 4,
        unitCost: 100,
      );

      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i017_acc',
          delta: 2,
          reason: 'correction',
        ),
      );

      final rows = await context.stockAdjustmentsForProduct('prd_i017_acc');
      expect(rows.length, 1);
      expect(rows.single['adjustment_type'], 'increase');
      expect(rows.single['quantity_delta'], 2);
      expect(rows.single['reason'], 'correction');
    });

    test(
        'I-018 Adjustment history visibility supports correct paging/filtering view',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i018_acc',
        name: 'I018 Accessory',
        sku: 'I018-ACC',
        purchasePrice: 70,
        salePrice: 110,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i018_acc',
        productName: 'I018 Accessory',
        quantity: 20,
        unitCost: 70,
      );

      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i018_acc',
          delta: 3,
          reason: 'correction',
        ),
      );
      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i018_acc',
          delta: -1,
          reason: 'damage',
        ),
      );

      final page1 = _expectSuccess(
        await context.operationsService
            .getStockAdjustments(limit: 1, offset: 0),
      );
      final page2 = _expectSuccess(
        await context.operationsService
            .getStockAdjustments(limit: 1, offset: 1),
      );

      expect(page1.length, 1);
      expect(page2.length, 1);
      expect(page1.single.id, isNot(equals(page2.single.id)));
      expect(
        {page1.single.adjustmentType, page2.single.adjustmentType},
        containsAll(<String>{'increase', 'decrease'}),
      );
    });

    test('I-019 Multiple adjustments keep accurate and ordered audit history',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i019_acc',
        name: 'I019 Accessory',
        sku: 'I019-ACC',
        purchasePrice: 90,
        salePrice: 140,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i019_acc',
        productName: 'I019 Accessory',
        quantity: 10,
        unitCost: 90,
      );

      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i019_acc',
          delta: 2,
          reason: 'correction',
        ),
      );
      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i019_acc',
          delta: -3,
          reason: 'damage',
        ),
      );
      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i019_acc',
          delta: 1,
          reason: 'correction',
        ),
      );

      final history = _expectSuccess(
          await context.operationsService.getStockAdjustments(limit: 10));
      final rows = history
          .where((row) => row.productName == 'I019 Accessory')
          .toList(growable: false);

      expect(rows.length, 3);
      expect(rows.map((row) => row.quantityDelta).toSet(), <int>{1, -3, 2});

      final createdAtEpoch =
          rows.map((row) => row.createdAt.millisecondsSinceEpoch).toList();
      final sorted = List<int>.from(createdAtEpoch)
        ..sort((a, b) => b.compareTo(a));
      expect(createdAtEpoch, sorted);
    });

    test('I-020 Failed adjustment is fully rolled back (no partial updates)',
        () async {
      final context = await _InventoryAdjustmentContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i020_acc',
        name: 'I020 Accessory',
        sku: 'I020-ACC',
        purchasePrice: 110,
        salePrice: 160,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i020_acc',
        productName: 'I020 Accessory',
        quantity: 5,
        unitCost: 110,
      );

      final beforeQty = await context.getAccessoryQuantity('prd_i020_acc');
      final beforeAudit = await context.countStockAdjustments();

      final failed =
          await context.operationsService.applyQuantityStockAdjustment(
        productModelId: 'prd_i020_acc',
        delta: -999,
        reason: 'damage',
      );

      expect(failed.isFailure, isTrue);
      expect(await context.getAccessoryQuantity('prd_i020_acc'), beforeQty);
      expect(await context.countStockAdjustments(), beforeAudit);
    });
  });
}

class _InventoryAdjustmentContext {
  _InventoryAdjustmentContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final OperationsWorkflowService operationsService;

  static Future<_InventoryAdjustmentContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase3_i011_i020_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);

    return _InventoryAdjustmentContext._(
      rootDirectory: rootDirectory,
      appDatabase: appDatabase,
    );
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }

  Future<ProductEntity> createProduct({
    required String id,
    required String name,
    required String sku,
    required double purchasePrice,
    required double salePrice,
    required bool hasImei,
  }) async {
    final now = DateTime.utc(2026, 5, 17);
    return _expectSuccess(
      await productRepository.createProduct(
        ProductEntity(
          id: id,
          name: name,
          sku: sku,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          hasImei: hasImei,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> purchaseAccessory({
    required String productModelId,
    required String productName,
    required int quantity,
    required double unitCost,
  }) async {
    _expectSuccess(
      await purchaseRepository.createPurchaseTransaction(
        items: <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: productModelId,
            productName: productName,
            hasImei: false,
            quantity: quantity,
            unitCost: unitCost,
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: unitCost * quantity,
      ),
    );
  }

  Future<void> purchasePhone({
    required String productModelId,
    required String productName,
    required String imei1,
    required double costPrice,
  }) async {
    _expectSuccess(
      await purchaseRepository.createPurchaseTransaction(
        items: <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: productModelId,
            productName: productName,
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: imei1, costPrice: costPrice),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: costPrice,
      ),
    );
  }

  Future<int> getAccessoryQuantity(String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return (rows.single['quantity'] as num).toInt();
  }

  Future<int> countStockAdjustments() async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.stockAdjustments}',
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<Map<String, Object?>> latestStockAdjustment() async {
    final rows = await appDatabase.queryTable(
      TableNames.stockAdjustments,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<List<Map<String, Object?>>> stockAdjustmentsForProduct(
    String productModelId,
  ) {
    return appDatabase.queryTable(
      TableNames.stockAdjustments,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      orderBy: 'created_at DESC',
    );
  }

  Future<String> getSerializedStockIdByImei(String imei1) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'imei1 = ?',
      whereArgs: <Object?>[imei1],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single['id'] as String;
  }

  Future<Map<String, Object?>> getSerializedById(String id) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
