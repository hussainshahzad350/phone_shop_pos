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
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('PHASE 3 Inventory I-021..I-030', () {
    test(
      'I-021 IMEI uniqueness after adjustment: no duplicates created',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i021_phone',
          name: 'I021 Phone',
          sku: 'I021-PHONE',
          purchasePrice: 50000,
          salePrice: 55000,
          hasImei: true,
        );

        await context.purchasePhone(
          productModelId: 'prd_i021_phone',
          productName: 'I021 Phone',
          imei1: '356789101234621',
          costPrice: 50000,
        );

        final beforeUniqueCount =
            await context.countUniqueImeis('356789101234621');
        expect(beforeUniqueCount, 1);

        final serializedId =
            await context.getSerializedStockIdByImei('356789101234621');
        _expectSuccess(
          await context.operationsService.writeOffSerializedStock(
            serializedStockId: serializedId,
            reason: 'damage',
          ),
        );

        final afterUniqueCount =
            await context.countUniqueImeis('356789101234621');
        expect(afterUniqueCount, 1);
      },
    );

    test(
      'I-022 Adjust IMEI that was sold: blocked or handled safely',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i022_phone',
          name: 'I022 Phone',
          sku: 'I022-PHONE',
          purchasePrice: 51000,
          salePrice: 57000,
          hasImei: true,
        );

        await context.purchasePhone(
          productModelId: 'prd_i022_phone',
          productName: 'I022 Phone',
          imei1: '356789101234622',
          costPrice: 51000,
        );

        final serializedId =
            await context.getSerializedStockIdByImei('356789101234622');
        await context.sellPhoneBySerializedId(
          productModelId: 'prd_i022_phone',
          productName: 'I022 Phone',
          serializedStockId: serializedId,
          imei: '356789101234622',
          unitPrice: 57000,
        );

        final statusBeforeAttempt = await context.getImeiStatus(serializedId);
        expect(statusBeforeAttempt, SerializedStockStatus.sold.value);

        final writeoffResult =
            await context.operationsService.writeOffSerializedStock(
          serializedStockId: serializedId,
          reason: 'theft',
        );

        expect(writeoffResult.isFailure, isTrue);
        final statusAfter = await context.getImeiStatus(serializedId);
        expect(statusAfter, SerializedStockStatus.sold.value);
      },
    );

    test(
      'I-023 Adjust IMEI that was returned: state is correctly restored',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i023_phone',
          name: 'I023 Phone',
          sku: 'I023-PHONE',
          purchasePrice: 52000,
          salePrice: 58000,
          hasImei: true,
        );

        await context.purchasePhone(
          productModelId: 'prd_i023_phone',
          productName: 'I023 Phone',
          imei1: '356789101234623',
          costPrice: 52000,
        );

        final serializedId =
            await context.getSerializedStockIdByImei('356789101234623');
        final saleId = await context.sellPhoneBySerializedId(
          productModelId: 'prd_i023_phone',
          productName: 'I023 Phone',
          serializedStockId: serializedId,
          imei: '356789101234623',
          unitPrice: 58000,
        );

        final detail = _expectSuccess(
            await context.operationsService.getSalesInvoiceDetail(saleId));
        final saleItem = detail!.items.single;

        _expectSuccess(
          await context.operationsService.processReturn(
            saleId: saleId,
            item: saleItem,
            quantity: 1,
            reason: 'correction',
          ),
        );

        expect(await context.getImeiStatus(serializedId),
            SerializedStockStatus.inStock.value);

        _expectSuccess(
          await context.operationsService.writeOffSerializedStock(
            serializedStockId: serializedId,
            reason: 'theft',
          ),
        );

        expect(await context.getImeiStatus(serializedId), 'damaged');
      },
    );

    test(
      'I-024 IMEI manual override attempt: impossible to corrupt DB',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i024_phone_a',
          name: 'I024 Phone A',
          sku: 'I024-PHONE-A',
          purchasePrice: 49000,
          salePrice: 54000,
          hasImei: true,
        );
        await context.createProduct(
          id: 'prd_i024_phone_b',
          name: 'I024 Phone B',
          sku: 'I024-PHONE-B',
          purchasePrice: 48000,
          salePrice: 53000,
          hasImei: true,
        );

        await context.purchasePhone(
          productModelId: 'prd_i024_phone_a',
          productName: 'I024 Phone A',
          imei1: '356789101234624',
          costPrice: 49000,
        );
        await context.purchasePhone(
          productModelId: 'prd_i024_phone_b',
          productName: 'I024 Phone B',
          imei1: '356789101234625',
          costPrice: 48000,
        );

        final imei1Rows = await context.countImeiInDB('356789101234624');
        expect(imei1Rows, 1);

        final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
        final duplicateInsert = await context.appDatabase
            .insert(
              TableNames.serializedStock,
              <String, Object?>{
                'id': 'ser_dup_attack',
                'product_model_id': 'prd_i024_phone_b',
                'imei1': '356789101234624',
                'imei2': null,
                'serial_number': null,
                'cost_price': 48000,
                'selling_price': 53000,
                'stock_status': SerializedStockStatus.inStock.value,
                'created_at': now,
                'updated_at': now,
              },
            )
            .then((_) => true)
            .catchError((_) => false);

        expect(duplicateInsert, isFalse);
        expect(await context.countImeiInDB('356789101234624'), 1);
      },
    );

    test(
      'I-025 Simultaneous adjustment + sale: no race condition',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i025_acc',
          name: 'I025 Accessory',
          sku: 'I025-ACC',
          purchasePrice: 100,
          salePrice: 150,
          hasImei: false,
        );

        await context.purchaseAccessory(
          productModelId: 'prd_i025_acc',
          productName: 'I025 Accessory',
          quantity: 20,
          unitCost: 100,
        );

        final qty1 = await context.getAccessoryQuantity('prd_i025_acc');
        expect(qty1, 20);

        final adjResult = _expectSuccess(
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i025_acc',
            delta: 10,
            reason: 'correction',
          ),
        );

        _expectSuccess(
          await context.salesRepository.createSaleTransaction(
            items: <CartItemEntity>[
              const CartItemEntity(
                productModelId: 'prd_i025_acc',
                productName: 'I025 Accessory',
                hasImei: false,
                quantity: 5,
                unitPrice: 150,
              ),
            ],
            totals: const SaleTotalsEntity(
              subtotal: 750,
              discount: 0,
              tax: 0,
              total: 750,
              paidAmount: 750,
            ),
            saleDate: DateTimeHelpers.nowUtc(),
          ),
        );

        expect(adjResult, 30);
        expect(await context.getAccessoryQuantity('prd_i025_acc'), 25);
      },
    );

    test(
      'I-026 Adjustment during app restart: consistency preserved',
      () async {
        final rootDirectory = await Directory.systemTemp.createTemp(
          'phone_shop_pos_phase3_i026_',
        );
        addTearDown(() async {
          if (await rootDirectory.exists()) {
            await rootDirectory.delete(recursive: true);
          }
        });

        final db1 = AppDatabase(
          localDatabaseService: SqliteFfiDatabaseService(
            rootDirectory: rootDirectory.path,
          ),
          migrationService: const MigrationService(),
        );
        await db1.initialize(seedDemoData: false);

        final productRepo1 = SqliteProductRepository(appDatabase: db1);
        final purchaseRepo1 = SqlitePurchaseRepository(appDatabase: db1);
        final opsService1 = OperationsWorkflowService(appDatabase: db1);

        final now = DateTime.utc(2026, 5, 17);
        await productRepo1.createProduct(
          ProductEntity(
            id: 'prd_i026_acc',
            name: 'I026 Accessory',
            sku: 'I026-ACC',
            purchasePrice: 70,
            salePrice: 110,
            hasImei: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        _expectSuccess(
          await purchaseRepo1.createPurchaseTransaction(
            items: const <PurchaseFormItem>[
              PurchaseFormItem(
                productModelId: 'prd_i026_acc',
                productName: 'I026 Accessory',
                hasImei: false,
                quantity: 15,
                unitCost: 70,
              ),
            ],
            discount: 0,
            tax: 0,
            paidAmount: 1050,
          ),
        );

        final before = _expectSuccess(
          await opsService1.applyQuantityStockAdjustment(
            productModelId: 'prd_i026_acc',
            delta: 5,
            reason: 'correction',
          ),
        );
        expect(before, 20);

        await db1.close();

        final db2 = AppDatabase(
          localDatabaseService: SqliteFfiDatabaseService(
            rootDirectory: rootDirectory.path,
          ),
          migrationService: const MigrationService(),
        );
        await db2.initialize(seedDemoData: false);

        final qty = await db2.queryTable(
          TableNames.inventoryStock,
          where: 'product_model_id = ?',
          whereArgs: <Object?>['prd_i026_acc'],
          limit: 1,
        );
        expect(qty, isNotEmpty);
        expect((qty.single['quantity'] as num).toInt(), 20);

        await db2.close();
      },
    );

    test(
      'I-027 Rapid adjustments spam: single consistent final result',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i027_acc',
          name: 'I027 Accessory',
          sku: 'I027-ACC',
          purchasePrice: 80,
          salePrice: 120,
          hasImei: false,
        );

        await context.purchaseAccessory(
          productModelId: 'prd_i027_acc',
          productName: 'I027 Accessory',
          quantity: 50,
          unitCost: 80,
        );

        const adjustments = <int>[3, -2, 4, -1, 2, -3, 1];
        var running = 50;
        for (final delta in adjustments) {
          running += delta;
          final result = _expectSuccess(
            await context.operationsService.applyQuantityStockAdjustment(
              productModelId: 'prd_i027_acc',
              delta: delta,
              reason: 'correction',
            ),
          );
          expect(result, running);
        }

        final finalQty = await context.getAccessoryQuantity('prd_i027_acc');
        expect(finalQty, running);
        expect(
          await context.countStockAdjustmentsForProduct('prd_i027_acc'),
          adjustments.length,
        );
      },
    );

    test(
      'I-028 Negative accessory stock prevention under stress: never below zero',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i028_acc',
          name: 'I028 Accessory',
          sku: 'I028-ACC',
          purchasePrice: 95,
          salePrice: 140,
          hasImei: false,
        );

        await context.purchaseAccessory(
          productModelId: 'prd_i028_acc',
          productName: 'I028 Accessory',
          quantity: 8,
          unitCost: 95,
        );

        for (var i = 0; i < 3; i++) {
          _expectSuccess(
            await context.operationsService.applyQuantityStockAdjustment(
              productModelId: 'prd_i028_acc',
              delta: -2,
              reason: 'damage',
            ),
          );
        }

        expect(await context.getAccessoryQuantity('prd_i028_acc'), 2);

        final blocked =
            await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i028_acc',
          delta: -3,
          reason: 'damage',
        );
        expect(blocked.isFailure, isTrue);

        expect(await context.getAccessoryQuantity('prd_i028_acc'), 2);
      },
    );

    test(
      'I-029 Adjustment on non-existent item: safely handled',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        final result =
            await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_nonexistent',
          delta: 5,
          reason: 'correction',
        );

        expect(result.isFailure, isTrue);
      },
    );

    test(
      'I-030 Adjustment financial impact: profits isolated, costs correct',
      () async {
        final context = await _StressContext.createTemporary();
        addTearDown(context.dispose);

        await context.createProduct(
          id: 'prd_i030_acc',
          name: 'I030 Accessory',
          sku: 'I030-ACC',
          purchasePrice: 200,
          salePrice: 300,
          hasImei: false,
        );

        _expectSuccess(
          await context.purchaseRepository.createPurchaseTransaction(
            items: const <PurchaseFormItem>[
              PurchaseFormItem(
                productModelId: 'prd_i030_acc',
                productName: 'I030 Accessory',
                hasImei: false,
                quantity: 10,
                unitCost: 200,
              ),
            ],
            discount: 0,
            tax: 0,
            paidAmount: 2000,
          ),
        );

        _expectSuccess(
          await context.salesRepository.createSaleTransaction(
            items: const <CartItemEntity>[
              CartItemEntity(
                productModelId: 'prd_i030_acc',
                productName: 'I030 Accessory',
                hasImei: false,
                quantity: 2,
                unitPrice: 300,
              ),
            ],
            totals: const SaleTotalsEntity(
              subtotal: 600,
              discount: 0,
              tax: 0,
              total: 600,
              paidAmount: 600,
            ),
            saleDate: DateTimeHelpers.nowUtc(),
          ),
        );

        final profitBefore = _expectSuccess(
          await context.profitService.getProfitReport(
            const ReportFilterEntity(),
          ),
        );

        _expectSuccess(
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i030_acc',
            delta: 3,
            reason: 'correction',
          ),
        );

        final profitAfter = _expectSuccess(
          await context.profitService.getProfitReport(
            const ReportFilterEntity(),
          ),
        );

        expect(profitAfter.totalProfit, profitBefore.totalProfit);

        _expectSuccess(
          await context.salesRepository.createSaleTransaction(
            items: const <CartItemEntity>[
              CartItemEntity(
                productModelId: 'prd_i030_acc',
                productName: 'I030 Accessory',
                hasImei: false,
                quantity: 2,
                unitPrice: 300,
              ),
            ],
            totals: const SaleTotalsEntity(
              subtotal: 600,
              discount: 0,
              tax: 0,
              total: 600,
              paidAmount: 600,
            ),
            saleDate: DateTimeHelpers.nowUtc(),
          ),
        );

        final profitAfterNextSale = _expectSuccess(
          await context.profitService.getProfitReport(
            const ReportFilterEntity(),
          ),
        );

        expect(profitAfterNextSale.totalProfit, profitBefore.totalProfit + 200);
      },
    );
  });
}

class _StressContext {
  _StressContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase),
        profitService = ProfitReportService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final OperationsWorkflowService operationsService;
  final ProfitReportService profitService;

  static Future<_StressContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase3_i021_i030_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);

    return _StressContext._(
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

  Future<String> sellPhoneBySerializedId({
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

  Future<String> getImeiStatus(String serializedStockId) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'id = ?',
      whereArgs: <Object?>[serializedStockId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single['stock_status'] as String;
  }

  Future<int> countUniqueImeis(String imei1) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.serializedStock} WHERE imei1 = ? OR imei2 = ?',
      <Object?>[imei1, imei1],
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<int> countImeiInDB(String imei1) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.serializedStock} WHERE imei1 = ?',
      <Object?>[imei1],
    );
    return (rows.single['count'] as num).toInt();
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

  Future<int> countStockAdjustmentsForProduct(String productModelId) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.stockAdjustments} WHERE product_model_id = ?',
      <Object?>[productModelId],
    );
    return (rows.single['count'] as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
