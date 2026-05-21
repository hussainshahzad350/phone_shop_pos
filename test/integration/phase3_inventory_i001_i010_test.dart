import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/services/inventory_service.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('PHASE 3 Inventory I-001..I-010', () {
    test('I-001 View inventory list: all visible, separated, no duplicates',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i001_phone_a',
        name: 'I001 Phone A',
        sku: 'I001-PHONE-A',
        purchasePrice: 50000,
        salePrice: 56000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_i001_phone_b',
        name: 'I001 Phone B',
        sku: 'I001-PHONE-B',
        purchasePrice: 52000,
        salePrice: 58000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_i001_acc_a',
        name: 'I001 Cable',
        sku: 'I001-ACC-A',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_i001_acc_b',
        name: 'I001 Charger',
        sku: 'I001-ACC-B',
        purchasePrice: 300,
        salePrice: 450,
        hasImei: false,
      );

      await context.purchasePhone(
        productModelId: 'prd_i001_phone_a',
        productName: 'I001 Phone A',
        imei1: '356789101234601',
        costPrice: 50000,
      );
      await context.purchasePhone(
        productModelId: 'prd_i001_phone_b',
        productName: 'I001 Phone B',
        imei1: '356789101234602',
        costPrice: 52000,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i001_acc_a',
        productName: 'I001 Cable',
        quantity: 12,
        unitCost: 100,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i001_acc_b',
        productName: 'I001 Charger',
        quantity: 7,
        unitCost: 300,
      );

      final rows =
          _expectSuccess(await context.inventoryService.getStockRows());
      expect(rows.length, 4);

      final serializedRows =
          rows.where((row) => row.type == StockRowType.serialized).toList();
      final quantityRows =
          rows.where((row) => row.type == StockRowType.quantity).toList();
      expect(serializedRows.length, 2);
      expect(quantityRows.length, 2);

      final uniqueKeys = rows
          .map(
            (row) =>
                '${row.type.name}|${row.productModelId}|${row.serializedStockId}|${row.inventoryStockId}',
          )
          .toSet();
      expect(uniqueKeys.length, rows.length);
    });

    test('I-002 Search inventory by name: fast and correctly filtered',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i002_acc_cable',
        name: 'I002 Fast Cable',
        sku: 'I002-CABLE',
        purchasePrice: 120,
        salePrice: 200,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_i002_acc_case',
        name: 'I002 Protective Case',
        sku: 'I002-CASE',
        purchasePrice: 180,
        salePrice: 260,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i002_acc_cable',
        productName: 'I002 Fast Cable',
        quantity: 15,
        unitCost: 120,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i002_acc_case',
        productName: 'I002 Protective Case',
        quantity: 8,
        unitCost: 180,
      );

      final stopwatch = Stopwatch()..start();
      final rows = _expectSuccess(
        await context.inventoryService.getStockRows(searchQuery: 'Cable'),
      );
      stopwatch.stop();

      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.productName.contains('Cable')), isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('I-003 Search by IMEI: exact phone returned with no duplicates',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i003_phone',
        name: 'I003 Phone',
        sku: 'I003-PHONE',
        purchasePrice: 47000,
        salePrice: 53000,
        hasImei: true,
      );
      await context.purchasePhone(
        productModelId: 'prd_i003_phone',
        productName: 'I003 Phone',
        imei1: '356789101234603',
        costPrice: 47000,
      );

      final exact = _expectSuccess(
          await context.inventoryService.searchByImei('356789101234603'));

      expect(exact.length, 1);
      expect(exact.single.imei1, '356789101234603');
      expect(exact.map((item) => item.id).toSet().length, exact.length);
    });

    test('I-004 Low stock filter: only low-stock rows are shown', () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i004_low',
        name: 'I004 Low Item',
        sku: 'I004-LOW',
        purchasePrice: 100,
        salePrice: 130,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_i004_ok',
        name: 'I004 Healthy Item',
        sku: 'I004-OK',
        purchasePrice: 100,
        salePrice: 130,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i004_low',
        productName: 'I004 Low Item',
        quantity: 2,
        unitCost: 100,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i004_ok',
        productName: 'I004 Healthy Item',
        quantity: 9,
        unitCost: 100,
      );

      await context.appDatabase.update(
        TableNames.inventoryStock,
        <String, Object?>{
          'min_quantity': 3,
          'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
        },
        where: 'product_model_id = ?',
        whereArgs: <Object?>['prd_i004_low'],
      );
      await context.appDatabase.update(
        TableNames.inventoryStock,
        <String, Object?>{
          'min_quantity': 4,
          'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
        },
        where: 'product_model_id = ?',
        whereArgs: <Object?>['prd_i004_ok'],
      );

      final lowRows =
          _expectSuccess(await context.inventoryService.getLowStockRows());
      expect(lowRows.length, 1);
      expect(lowRows.single.productModelId, 'prd_i004_low');
      expect(lowRows.single.isLowStock, isTrue);
    });

    test('I-005 Out-of-stock rows remain visible and correctly marked',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i005_phone',
        name: 'I005 Phone',
        sku: 'I005-PHONE',
        purchasePrice: 49000,
        salePrice: 54000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_i005_acc',
        name: 'I005 Accessory',
        sku: 'I005-ACC',
        purchasePrice: 150,
        salePrice: 220,
        hasImei: false,
      );

      await context.purchasePhone(
        productModelId: 'prd_i005_phone',
        productName: 'I005 Phone',
        imei1: '356789101234604',
        costPrice: 49000,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i005_acc',
        productName: 'I005 Accessory',
        quantity: 1,
        unitCost: 150,
      );

      final serializedId =
          await context.getSerializedStockIdByImei('356789101234604');
      await context.sellPhone(
        productModelId: 'prd_i005_phone',
        productName: 'I005 Phone',
        serializedStockId: serializedId,
        imei: '356789101234604',
        unitPrice: 54000,
      );
      await context.sellAccessory(
        productModelId: 'prd_i005_acc',
        productName: 'I005 Accessory',
        quantity: 1,
        unitPrice: 220,
      );

      final rows =
          _expectSuccess(await context.inventoryService.getStockRows());

      final soldPhone = rows.firstWhere(
        (row) => row.productModelId == 'prd_i005_phone',
      );
      final outAccessory = rows.firstWhere(
        (row) => row.productModelId == 'prd_i005_acc',
      );

      expect(soldPhone.serializedStatus, SerializedStockStatus.sold);
      expect(outAccessory.quantity, 0);
    });

    test('I-006 Stock after sale consistency: reduced exactly once', () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i006_acc',
        name: 'I006 Accessory',
        sku: 'I006-ACC',
        purchasePrice: 100,
        salePrice: 170,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i006_acc',
        productName: 'I006 Accessory',
        quantity: 5,
        unitCost: 100,
      );

      final before = await context.getAccessoryQuantity('prd_i006_acc');
      await context.sellAccessory(
        productModelId: 'prd_i006_acc',
        productName: 'I006 Accessory',
        quantity: 2,
        unitPrice: 170,
      );
      final after = await context.getAccessoryQuantity('prd_i006_acc');

      expect(before, 5);
      expect(after, 3);
      expect(before - after, 2);
    });

    test('I-007 Stock after purchase consistency: increases correctly',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i007_acc',
        name: 'I007 Accessory',
        sku: 'I007-ACC',
        purchasePrice: 200,
        salePrice: 280,
        hasImei: false,
      );

      await context.purchaseAccessory(
        productModelId: 'prd_i007_acc',
        productName: 'I007 Accessory',
        quantity: 3,
        unitCost: 200,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i007_acc',
        productName: 'I007 Accessory',
        quantity: 2,
        unitCost: 220,
      );

      expect(await context.getAccessoryQuantity('prd_i007_acc'), 5);
    });

    test('I-008 Stock after return (phone): IMEI restored to in-stock',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i008_phone',
        name: 'I008 Phone',
        sku: 'I008-PHONE',
        purchasePrice: 60000,
        salePrice: 67000,
        hasImei: true,
      );
      await context.purchasePhone(
        productModelId: 'prd_i008_phone',
        productName: 'I008 Phone',
        imei1: '356789101234605',
        costPrice: 60000,
      );

      final serializedId =
          await context.getSerializedStockIdByImei('356789101234605');
      final saleId = await context.sellPhone(
        productModelId: 'prd_i008_phone',
        productName: 'I008 Phone',
        serializedStockId: serializedId,
        imei: '356789101234605',
        unitPrice: 67000,
      );

      final detail = _expectSuccess(
          await context.operationsService.getSalesInvoiceDetail(saleId));
      expect(detail, isNotNull);
      final saleItem = detail!.items.single;

      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleId,
          item: saleItem,
          quantity: 1,
          reason: 'correction',
        ),
      );

      final row = await context.getSerializedStockById(serializedId);
      expect(row['stock_status'], SerializedStockStatus.inStock.value);
    });

    test('I-009 Stock after return (accessory): quantity restored', () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i009_acc',
        name: 'I009 Accessory',
        sku: 'I009-ACC',
        purchasePrice: 110,
        salePrice: 180,
        hasImei: false,
      );
      await context.purchaseAccessory(
        productModelId: 'prd_i009_acc',
        productName: 'I009 Accessory',
        quantity: 10,
        unitCost: 110,
      );

      final saleId = await context.sellAccessory(
        productModelId: 'prd_i009_acc',
        productName: 'I009 Accessory',
        quantity: 3,
        unitPrice: 180,
      );

      final detail = _expectSuccess(
          await context.operationsService.getSalesInvoiceDetail(saleId));
      expect(detail, isNotNull);
      final saleItem = detail!.items.single;

      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleId,
          item: saleItem,
          quantity: 2,
          reason: 'correction',
        ),
      );

      expect(await context.getAccessoryQuantity('prd_i009_acc'), 9);
    });

    test(
        'I-010 Mixed operations consistency: final stock is mathematically correct',
        () async {
      final context = await _InventoryBatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_i010_acc',
        name: 'I010 Accessory',
        sku: 'I010-ACC',
        purchasePrice: 200,
        salePrice: 300,
        hasImei: false,
      );

      const purchased = 20;
      const sold = 8;
      const returned = 3;
      const adjustment = -4;

      await context.purchaseAccessory(
        productModelId: 'prd_i010_acc',
        productName: 'I010 Accessory',
        quantity: purchased,
        unitCost: 200,
      );
      final saleId = await context.sellAccessory(
        productModelId: 'prd_i010_acc',
        productName: 'I010 Accessory',
        quantity: sold,
        unitPrice: 300,
      );

      final detail = _expectSuccess(
          await context.operationsService.getSalesInvoiceDetail(saleId));
      final saleItem = detail!.items.single;

      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleId,
          item: saleItem,
          quantity: returned,
          reason: 'correction',
        ),
      );

      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i010_acc',
          delta: adjustment,
          reason: 'correction',
        ),
      );

      const expected = purchased + returned + adjustment - sold;
      final actual = await context.getAccessoryQuantity('prd_i010_acc');
      expect(actual, expected);
    });
  });
}

class _InventoryBatchContext {
  _InventoryBatchContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        inventoryService = InventoryService(
          repository: SqliteInventoryRepository(appDatabase: appDatabase),
        ),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final InventoryService inventoryService;
  final OperationsWorkflowService operationsService;

  static Future<_InventoryBatchContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase3_i001_i010_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);

    return _InventoryBatchContext._(
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
              ImeiEntry(
                imei1: imei1,
                costPrice: costPrice,
              ),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: costPrice,
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

  Future<String> sellPhone({
    required String productModelId,
    required String productName,
    required String serializedStockId,
    required String imei,
    required double unitPrice,
  }) async {
    final completion = _expectSuccess(
      await salesRepository.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productModelId,
            productName: productName,
            hasImei: true,
            quantity: 1,
            unitPrice: unitPrice,
            serializedStockId: serializedStockId,
            imei: imei,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: unitPrice,
          discount: 0,
          tax: 0,
          total: unitPrice,
          paidAmount: unitPrice,
        ),
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }

  Future<String> sellAccessory({
    required String productModelId,
    required String productName,
    required int quantity,
    required double unitPrice,
  }) async {
    final subtotal = unitPrice * quantity;
    final completion = _expectSuccess(
      await salesRepository.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productModelId,
            productName: productName,
            hasImei: false,
            quantity: quantity,
            unitPrice: unitPrice,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: subtotal,
          discount: 0,
          tax: 0,
          total: subtotal,
          paidAmount: subtotal,
        ),
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }

  Future<String> getSerializedStockIdByImei(String imei) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'imei1 = ?',
      whereArgs: <Object?>[imei],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single['id'] as String;
  }

  Future<Map<String, Object?>> getSerializedStockById(String id) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
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
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
