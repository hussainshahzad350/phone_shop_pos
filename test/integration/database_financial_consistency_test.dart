import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/services/dashboard_service.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/inventory_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/sales_report_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Database integrity and financial consistency hardening', () {
    test('migration v7 fails gracefully when duplicate imei2 already exists',
        () async {
      final root = await Directory.systemTemp.createTemp(
        'phone_shop_pos_migration_v7_',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final v6Database = AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
        migrationService: const _MigrationServiceV6(),
      );
      await v6Database.initialize(seedDemoData: false);

      final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
      await v6Database.insert(TableNames.productModels, <String, Object?>{
        'id': 'prd_dup_imei2',
        'name': 'Duplicate IMEI2 Phone',
        'brand': 'Brand',
        'category': 'Phones',
        'sku': 'DUP-IMEI2-PHONE',
        'purchase_price': 10000,
        'sale_price': 12000,
        'has_imei': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await v6Database.insert(TableNames.serializedStock, <String, Object?>{
        'id': 'ser_dup_1',
        'product_model_id': 'prd_dup_imei2',
        'imei1': '356789101234501',
        'imei2': '356789101234599',
        'serial_number': 'DUP-SER-1',
        'cost_price': 10000,
        'selling_price': 12000,
        'stock_status': 'in_stock',
        'created_at': now,
        'updated_at': now,
      });
      await v6Database.insert(TableNames.serializedStock, <String, Object?>{
        'id': 'ser_dup_2',
        'product_model_id': 'prd_dup_imei2',
        'imei1': '356789101234502',
        'imei2': '356789101234599',
        'serial_number': 'DUP-SER-2',
        'cost_price': 10000,
        'selling_price': 12000,
        'stock_status': 'in_stock',
        'created_at': now,
        'updated_at': now,
      });
      await v6Database.close();

      final upgradedDatabase = AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
        migrationService: const MigrationService(),
      );

      await expectLater(
        upgradedDatabase.initialize(seedDemoData: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('duplicate non-null serialized_stock.imei2 values found'),
          ),
        ),
      );
    });

    test('migration v7 enforces database-level unique imei2 index', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_imei2_unique',
        name: 'IMEI2 Unique Phone',
        sku: 'PHONE-IMEI2-UNQ',
        purchasePrice: 70000,
        salePrice: 76000,
        hasImei: true,
      );

      final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
      await context.appDatabase.insert(TableNames.serializedStock, <String, Object?>{
        'id': 'ser_unique_1',
        'product_model_id': 'prd_imei2_unique',
        'imei1': '356789101234511',
        'imei2': '356789101234577',
        'serial_number': 'SER-UNQ-1',
        'cost_price': 70000,
        'selling_price': 76000,
        'stock_status': 'in_stock',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        context.appDatabase.insert(TableNames.serializedStock, <String, Object?>{
          'id': 'ser_unique_2',
          'product_model_id': 'prd_imei2_unique',
          'imei1': '356789101234512',
          'imei2': '356789101234577',
          'serial_number': 'SER-UNQ-2',
          'cost_price': 70000,
          'selling_price': 76000,
          'stock_status': 'in_stock',
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('weighted-average cost is used for repeated accessory purchases',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_weighted_avg',
        name: 'Weighted Avg Accessory',
        sku: 'ACC-WAVG-001',
        purchasePrice: 100,
        salePrice: 180,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_weighted_avg',
              productName: 'Weighted Avg Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1000,
        ),
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_weighted_avg',
              productName: 'Weighted Avg Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 300,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 3000,
        ),
      );

      final weightedRows = await context.appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>['prd_weighted_avg'],
        limit: 1,
      );
      expect(weightedRows, isNotEmpty);
      expect(weightedRows.first['quantity'], 20);
      expect(
        (weightedRows.first['unit_cost'] as num?)?.toDouble(),
        closeTo(200, 0.0001),
      );

      await context.createProduct(
        id: 'prd_weighted_zero',
        name: 'Weighted Zero Qty',
        sku: 'ACC-WAVG-002',
        purchasePrice: 50,
        salePrice: 80,
        hasImei: false,
      );

      final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
      await context.appDatabase.insert(TableNames.inventoryStock, <String, Object?>{
        'id': 'stk_weighted_zero',
        'product_model_id': 'prd_weighted_zero',
        'quantity': 0,
        'min_quantity': 0,
        'unit_cost': 999,
        'unit_price': 0,
        'created_at': now,
        'updated_at': now,
      });

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_weighted_zero',
              productName: 'Weighted Zero Qty',
              hasImei: false,
              quantity: 4,
              unitCost: 250,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1000,
        ),
      );

      final zeroRows = await context.appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>['prd_weighted_zero'],
        limit: 1,
      );
      expect(zeroRows, isNotEmpty);
      expect(zeroRows.first['quantity'], 4);
      expect(
        (zeroRows.first['unit_cost'] as num?)?.toDouble(),
        closeTo(250, 0.0001),
      );
    });

    test(
        'profit remains immutable and matches dashboard/sales/profit report calculations',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final start = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final end = start;

      await context.createProduct(
        id: 'prd_profit_consistency',
        name: 'Profit Consistency Accessory',
        sku: 'ACC-PROFIT-001',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_profit_consistency',
              productName: 'Profit Consistency Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1000,
        ),
      );

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_profit_consistency',
              productName: 'Profit Consistency Accessory',
              hasImei: false,
              quantity: 2,
              unitPrice: 150,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 300,
            discount: 0,
            tax: 0,
            total: 300,
            paidAmount: 300,
          ),
          saleDate: todayUtc,
        ),
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_profit_consistency',
              productName: 'Profit Consistency Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 300,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 3000,
        ),
      );

      final filter = ReportFilterEntity(startDate: start, endDate: end);
      final profit = _expectSuccess(await context.profitReportService.getProfitReport(filter));
      final dailyRows = _expectSuccess(
        await context.salesReportService.getDailySalesReport(filter),
      );
      final dashboard = _expectSuccess(await context.dashboardService.getDashboardKpis());

      expect(profit.totalProfit, closeTo(100, 0.0001));
      expect(dailyRows, isNotEmpty);
      expect(dailyRows.first.totalProfit, closeTo(100, 0.0001));
      expect(dashboard.todayProfit, closeTo(100, 0.0001));
      expect(dailyRows.first.totalProfit, closeTo(profit.totalProfit, 0.0001));
      expect(dashboard.todayProfit, closeTo(profit.totalProfit, 0.0001));
    });

    test(
        'daily sales report does not multiply invoice totals by sale item count',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final day = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);

      await context.createProduct(
        id: 'prd_daily_no_dup_1',
        name: 'Daily Report Accessory 1',
        sku: 'ACC-DAILY-NODUP-1',
        purchasePrice: 50,
        salePrice: 120,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_daily_no_dup_2',
        name: 'Daily Report Accessory 2',
        sku: 'ACC-DAILY-NODUP-2',
        purchasePrice: 80,
        salePrice: 180,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_daily_no_dup_1',
              productName: 'Daily Report Accessory 1',
              hasImei: false,
              quantity: 5,
              unitCost: 50,
            ),
            PurchaseFormItem(
              productModelId: 'prd_daily_no_dup_2',
              productName: 'Daily Report Accessory 2',
              hasImei: false,
              quantity: 5,
              unitCost: 80,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 650,
        ),
      );

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_daily_no_dup_1',
              productName: 'Daily Report Accessory 1',
              hasImei: false,
              quantity: 1,
              unitPrice: 120,
            ),
            CartItemEntity(
              productModelId: 'prd_daily_no_dup_2',
              productName: 'Daily Report Accessory 2',
              hasImei: false,
              quantity: 1,
              unitPrice: 180,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 300,
            discount: 0,
            tax: 0,
            total: 300,
            paidAmount: 100,
          ),
          saleDate: todayUtc,
        ),
      );

      final rows = _expectSuccess(
        await context.salesReportService.getDailySalesReport(
          ReportFilterEntity(startDate: day, endDate: day),
        ),
      );

      expect(rows, hasLength(1));
      expect(rows.first.invoiceCount, 1);
      expect(rows.first.totalSales, closeTo(300, 0.0001));
      expect(rows.first.pendingBalances, closeTo(200, 0.0001));
      expect(rows.first.totalProfit, closeTo(170, 0.0001));
    });

    test('sold phones report uses sale_items cost snapshot only', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final day = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);

      await context.createProduct(
        id: 'prd_profit_phone_snapshot',
        name: 'Profit Snapshot Phone',
        sku: 'PHONE-PROFIT-001',
        purchasePrice: 50000,
        salePrice: 55000,
        hasImei: true,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_profit_phone_snapshot',
              productName: 'Profit Snapshot Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(
                  imei1: '356789101234650',
                  imei2: '356789101234668',
                  serialNumber: 'SNAP-IMEI-001',
                  costPrice: 50000,
                  sellingPrice: 55000,
                ),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 50000,
        ),
      );

      final serializedRowsBefore = await context.appDatabase.queryTable(
        TableNames.serializedStock,
        where: 'product_model_id = ?',
        whereArgs: const <Object?>['prd_profit_phone_snapshot'],
        limit: 1,
      );
      expect(serializedRowsBefore, isNotEmpty);
      final serializedId = serializedRowsBefore.first['id'] as String;

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_profit_phone_snapshot',
              productName: 'Profit Snapshot Phone',
              hasImei: true,
              quantity: 1,
              unitPrice: 55000,
              serializedStockId: serializedId,
              imei: '356789101234650',
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 55000,
            discount: 0,
            tax: 0,
            total: 55000,
            paidAmount: 55000,
          ),
          saleDate: todayUtc,
        ),
      );

      await context.appDatabase.update(
        TableNames.serializedStock,
        <String, Object?>{'cost_price': 99999},
        where: 'id = ?',
        whereArgs: <Object?>[serializedId],
      );
      await context.appDatabase.update(
        TableNames.productModels,
        <String, Object?>{'purchase_price': 123456},
        where: 'id = ?',
        whereArgs: const <Object?>['prd_profit_phone_snapshot'],
      );

      final rows = _expectSuccess(
        await context.salesReportService.getSoldPhonesReport(
          ReportFilterEntity(startDate: day, endDate: day),
        ),
      );

      expect(rows, isNotEmpty);
      expect(rows.first.costPrice, closeTo(50000, 0.0001));
      expect(rows.first.profit, closeTo(5000, 0.0001));
    });

    test('purchase repository rejects invalid IMEI format on direct call', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_bypass_invalid_imei',
        name: 'Bypass Invalid IMEI Phone',
        sku: 'PHONE-BYPASS-001',
        purchasePrice: 10000,
        salePrice: 12000,
        hasImei: true,
      );

      final result = await context.purchaseRepository.createPurchaseTransaction(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_bypass_invalid_imei',
            productName: 'Bypass Invalid IMEI Phone',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: 'invalid-imei', costPrice: 10000),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      expect(result.isFailure, isTrue);
    });

    test('inventory repository blocks direct serialized insert IMEI bypass', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);
      final inventoryRepository = SqliteInventoryRepository(
        appDatabase: context.appDatabase,
      );

      await context.createProduct(
        id: 'prd_inventory_imei_guard',
        name: 'Inventory Guard Phone',
        sku: 'PHONE-INV-GUARD-001',
        purchasePrice: 20000,
        salePrice: 23000,
        hasImei: true,
      );

      final now = DateTime.utc(2026, 5, 16);
      final invalidInsert = await inventoryRepository.addSerializedStock(
        SerializedStockEntity(
          id: 'ser_invalid_guard',
          productModelId: 'prd_inventory_imei_guard',
          imei1: 'not-valid',
          stockStatus: SerializedStockStatus.inStock,
          costPrice: 20000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(invalidInsert.isFailure, isTrue);

      final firstInsert = await inventoryRepository.addSerializedStock(
        SerializedStockEntity(
          id: 'ser_valid_guard_1',
          productModelId: 'prd_inventory_imei_guard',
          imei1: '356789101234677',
          stockStatus: SerializedStockStatus.inStock,
          costPrice: 20000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(firstInsert.isSuccess, isTrue);

      final duplicateInsert = await inventoryRepository.addSerializedStock(
        SerializedStockEntity(
          id: 'ser_valid_guard_2',
          productModelId: 'prd_inventory_imei_guard',
          imei1: '356789101234677',
          stockStatus: SerializedStockStatus.inStock,
          costPrice: 20000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(duplicateInsert.isFailure, isTrue);
    });

    test('customer balance report groups by customer id and keeps walk-ins',
        () async {      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final nowSql = DateTimeHelpers.toSql(todayUtc);

      await context.createProduct(
        id: 'prd_customer_grouping',
        name: 'Customer Grouping Accessory',
        sku: 'ACC-CUST-001',
        purchasePrice: 20,
        salePrice: 100,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_customer_grouping',
              productName: 'Customer Grouping Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 20,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 200,
        ),
      );

      await context.appDatabase.insert(TableNames.customers, <String, Object?>{
        'id': 'cus_same_1',
        'name': 'Same Name',
        'phone': '03000000001',
        'email': null,
        'address': null,
        'created_at': nowSql,
        'updated_at': nowSql,
        'notes': null,
        'is_active': 1,
      });
      await context.appDatabase.insert(TableNames.customers, <String, Object?>{
        'id': 'cus_same_2',
        'name': 'Same Name',
        'phone': '03000000002',
        'email': null,
        'address': null,
        'created_at': nowSql,
        'updated_at': nowSql,
        'notes': null,
        'is_active': 1,
      });

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_customer_grouping',
              productName: 'Customer Grouping Accessory',
              hasImei: false,
              quantity: 1,
              unitPrice: 100,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 100,
            discount: 0,
            tax: 0,
            total: 100,
            paidAmount: 50,
          ),
          saleDate: todayUtc,
          customerId: 'cus_same_1',
        ),
      );

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_customer_grouping',
              productName: 'Customer Grouping Accessory',
              hasImei: false,
              quantity: 1,
              unitPrice: 100,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 100,
            discount: 0,
            tax: 0,
            total: 100,
            paidAmount: 20,
          ),
          saleDate: todayUtc,
          customerId: 'cus_same_2',
        ),
      );

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_customer_grouping',
              productName: 'Customer Grouping Accessory',
              hasImei: false,
              quantity: 1,
              unitPrice: 60,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 60,
            discount: 0,
            tax: 0,
            total: 60,
            paidAmount: 0,
          ),
          saleDate: todayUtc,
        ),
      );

      final filter = ReportFilterEntity(
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
        endDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final balances = _expectSuccess(
        await context.inventoryReportService.getCustomerBalanceReport(filter),
      );

      expect(balances.length, 3);
      expect(
        balances.where((row) => row.customerName == 'Same Name').length,
        2,
      );
      expect(
        balances.any((row) => row.customerName == 'Walk-in Customer'),
        isTrue,
      );
    });

    // ── Return Model (Option A — Refund Model) tests ──────────────────────

    test('accessory return reduces sales.total and sales.paid_amount', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();

      await context.createProduct(
        id: 'prd_return_acc',
        name: 'Return Accessory',
        sku: 'ACC-RET-001',
        purchasePrice: 100,
        salePrice: 200,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_return_acc',
              productName: 'Return Accessory',
              hasImei: false,
              quantity: 5,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 500,
        ),
      );

      final saleResult = _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_return_acc',
              productName: 'Return Accessory',
              hasImei: false,
              quantity: 2,
              unitPrice: 200,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 400,
            discount: 0,
            tax: 0,
            total: 400,
            paidAmount: 300,
          ),
          saleDate: todayUtc,
        ),
      );

      final detail = _expectSuccess(
        await context.operationsService.getSalesInvoiceDetail(saleResult.saleId),
      );
      expect(detail, isNotNull);
      final returnItem = detail!.items.first;

      // Return 1 of 2 units at 200 each → return_amount = 200
      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleResult.saleId,
          item: returnItem,
          quantity: 1,
          reason: 'defective',
        ),
      );

      final saleRows = await context.appDatabase.queryTable(
        TableNames.sales,
        where: 'id = ?',
        whereArgs: <Object?>[saleResult.saleId],
        limit: 1,
      );
      expect(saleRows, isNotEmpty);
      // total reduced: 400 - 200 = 200
      expect(
        (saleRows.first['total'] as num?)?.toDouble(),
        closeTo(200, 0.0001),
      );
      // paid clamped to new total: MIN(300, 200) = 200
      expect(
        (saleRows.first['paid_amount'] as num?)?.toDouble(),
        closeTo(200, 0.0001),
      );
    });

    test('return reduces profit in profit report and daily sales report',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final day = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);

      await context.createProduct(
        id: 'prd_return_profit',
        name: 'Return Profit Accessory',
        sku: 'ACC-RET-PROFIT-001',
        purchasePrice: 100,
        salePrice: 300,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_return_profit',
              productName: 'Return Profit Accessory',
              hasImei: false,
              quantity: 4,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 400,
        ),
      );

      // Sell 2 units @ 300 each; total = 600, paid = 600.
      // Gross profit = 2 × (300 - 100) = 400.
      final saleResult = _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_return_profit',
              productName: 'Return Profit Accessory',
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
          saleDate: todayUtc,
        ),
      );

      final filter = ReportFilterEntity(startDate: day, endDate: day);

      // Verify pre-return profit = 400
      final profitBefore =
          _expectSuccess(await context.profitReportService.getProfitReport(filter));
      expect(profitBefore.totalProfit, closeTo(400, 0.0001));

      final detail = _expectSuccess(
        await context.operationsService.getSalesInvoiceDetail(saleResult.saleId),
      );
      final returnItem = detail!.items.first;

      // Return 1 unit → return_amount = 300, return_cost = 100
      // Net profit after return = 400 - (300 - 100) = 200
      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleResult.saleId,
          item: returnItem,
          quantity: 1,
          reason: 'customer changed mind',
        ),
      );

      final profitAfter =
          _expectSuccess(await context.profitReportService.getProfitReport(filter));
      expect(profitAfter.totalProfit, closeTo(200, 0.0001));
      expect(profitAfter.totalRevenue, closeTo(300, 0.0001));
      expect(profitAfter.totalCost, closeTo(100, 0.0001));

      final dailyRows = _expectSuccess(
        await context.salesReportService.getDailySalesReport(filter),
      );
      expect(dailyRows, isNotEmpty);
      expect(dailyRows.first.totalProfit, closeTo(200, 0.0001));
      // total_sales reflects updated sales.total = 600 - 300 = 300
      expect(dailyRows.first.totalSales, closeTo(300, 0.0001));
      // fully paid after clamp (paid_amount was 600, clamped to 300)
      expect(dailyRows.first.pendingBalances, closeTo(0, 0.0001));
    });

    test('return reduces dashboard today_profit', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();

      await context.createProduct(
        id: 'prd_return_dash',
        name: 'Return Dashboard Accessory',
        sku: 'ACC-RET-DASH-001',
        purchasePrice: 50,
        salePrice: 150,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_return_dash',
              productName: 'Return Dashboard Accessory',
              hasImei: false,
              quantity: 3,
              unitCost: 50,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 150,
        ),
      );

      // Sell 2 units @ 150 each; profit = 2 × 100 = 200
      final saleResult = _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_return_dash',
              productName: 'Return Dashboard Accessory',
              hasImei: false,
              quantity: 2,
              unitPrice: 150,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 300,
            discount: 0,
            tax: 0,
            total: 300,
            paidAmount: 300,
          ),
          saleDate: todayUtc,
        ),
      );

      final dashBefore =
          _expectSuccess(await context.dashboardService.getDashboardKpis());
      expect(dashBefore.todayProfit, closeTo(200, 0.0001));

      final detail = _expectSuccess(
        await context.operationsService.getSalesInvoiceDetail(saleResult.saleId),
      );
      // Return both units → return_profit = 200, net profit = 0
      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleResult.saleId,
          item: detail!.items.first,
          quantity: 2,
          reason: 'wrong product',
        ),
      );

      // Flush the dashboard cache so the next call re-queries the DB.
      context.dashboardService.clearCache();

      final dashAfter =
          _expectSuccess(await context.dashboardService.getDashboardKpis());
      expect(dashAfter.todayProfit, closeTo(0, 0.0001));
    });

    test('partially-paid sale pending balance is correct after return', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();
      final day = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);

      await context.createProduct(
        id: 'prd_return_pending',
        name: 'Return Pending Accessory',
        sku: 'ACC-RET-PEND-001',
        purchasePrice: 40,
        salePrice: 100,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_return_pending',
              productName: 'Return Pending Accessory',
              hasImei: false,
              quantity: 5,
              unitCost: 40,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 200,
        ),
      );

      // Sell 3 units @ 100 each; total = 300, paid = 100 → pending = 200
      final saleResult = _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: const <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_return_pending',
              productName: 'Return Pending Accessory',
              hasImei: false,
              quantity: 3,
              unitPrice: 100,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 300,
            discount: 0,
            tax: 0,
            total: 300,
            paidAmount: 100,
          ),
          saleDate: todayUtc,
        ),
      );

      final detail = _expectSuccess(
        await context.operationsService.getSalesInvoiceDetail(saleResult.saleId),
      );

      // Return 1 unit @ 100 → new total = 200, paid stays 100 → pending = 100
      _expectSuccess(
        await context.operationsService.processReturn(
          saleId: saleResult.saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'excess order',
        ),
      );

      final filter = ReportFilterEntity(startDate: day, endDate: day);
      final dailyRows = _expectSuccess(
        await context.salesReportService.getDailySalesReport(filter),
      );
      expect(dailyRows, isNotEmpty);
      expect(dailyRows.first.totalSales, closeTo(200, 0.0001));
      expect(dailyRows.first.pendingBalances, closeTo(100, 0.0001));
    });

    // ── Payment integrity invariants ──────────────────────────────────────

    test('repository rejects sale where paid_amount exceeds total', () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final todayUtc = DateTimeHelpers.nowUtc();

      await context.createProduct(
        id: 'prd_overpay_guard',
        name: 'Overpay Guard Accessory',
        sku: 'ACC-OVERPAY-001',
        purchasePrice: 100,
        salePrice: 500,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_overpay_guard',
              productName: 'Overpay Guard Accessory',
              hasImei: false,
              quantity: 5,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 500,
        ),
      );

      // total = 500 but paid_amount = 9999 — must be rejected
      final result = await context.salesRepository.createSaleTransaction(
        items: const <CartItemEntity>[
          CartItemEntity(
            productModelId: 'prd_overpay_guard',
            productName: 'Overpay Guard Accessory',
            hasImei: false,
            quantity: 1,
            unitPrice: 500,
          ),
        ],
        totals: const SaleTotalsEntity(
          subtotal: 500,
          discount: 0,
          tax: 0,
          total: 500,
          paidAmount: 9999,
        ),
        saleDate: todayUtc,
      );

      expect(result.isFailure, isTrue,
          reason: 'overpayment must be rejected by the repository');
    });

    test('DB constraint rejects direct sales insert where paid_amount > total',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

      await expectLater(
        context.appDatabase.insert(TableNames.sales, <String, Object?>{
          'id': 'sal_db_overpay',
          'invoice_number': 'INV-DB-OVERPAY-0001',
          'customer_id': null,
          'user_id': null,
          'sale_date': now,
          'subtotal': 1000.0,
          'discount': 0.0,
          'tax': 0.0,
          'total': 1000.0,
          'paid_amount': 9999.0, // violates paid_amount <= total
          'payment_method': null,
          'notes': null,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('DB constraint rejects direct sales insert where paid_amount is negative',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

      await expectLater(
        context.appDatabase.insert(TableNames.sales, <String, Object?>{
          'id': 'sal_db_negpaid',
          'invoice_number': 'INV-DB-NEGPAID-0001',
          'customer_id': null,
          'user_id': null,
          'sale_date': now,
          'subtotal': 1000.0,
          'discount': 0.0,
          'tax': 0.0,
          'total': 1000.0,
          'paid_amount': -1.0, // violates paid_amount >= 0
          'payment_method': null,
          'notes': null,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('DB constraint rejects direct sales insert where total is negative',
        () async {
      final context = await _ConsistencyContext.createTemporary();
      addTearDown(context.dispose);

      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

      await expectLater(
        context.appDatabase.insert(TableNames.sales, <String, Object?>{
          'id': 'sal_db_negtotal',
          'invoice_number': 'INV-DB-NEGTOTAL-0001',
          'customer_id': null,
          'user_id': null,
          'sale_date': now,
          'subtotal': 0.0,
          'discount': 0.0,
          'tax': 0.0,
          'total': -1.0, // violates total >= 0
          'paid_amount': 0.0,
          'payment_method': null,
          'notes': null,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('migration v12 clamps legacy overpayment rows on upgrade', () async {
      // Build a v11 database with a corrupted row (paid_amount > total),
      // then upgrade to v12 and verify the row is clamped.
      final root =
          await Directory.systemTemp.createTemp('phone_shop_pos_v12_clamp_');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final v11Database = AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
        migrationService: const _MigrationServiceV11(),
      );
      await v11Database.initialize(seedDemoData: false);

      // Insert a deliberately corrupted row — no CHECK constraints exist yet
      // in v11 so this succeeds.
      final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
      await v11Database.insert(TableNames.sales, <String, Object?>{
        'id': 'sal_legacy_overpay',
        'invoice_number': 'INV-LEGACY-OVERPAY-0001',
        'customer_id': null,
        'user_id': null,
        'sale_date': now,
        'subtotal': 1000.0,
        'discount': 0.0,
        'tax': 0.0,
        'total': 1000.0,
        'paid_amount': 5000.0, // intentionally corrupted
        'payment_method': null,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await v11Database.close();

      // Upgrade to v12 — must succeed and clamp the corrupted row.
      final v12Database = AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
        migrationService: const MigrationService(),
      );
      await v12Database.initialize(seedDemoData: false);

      final rows = await v12Database.queryTable(
        TableNames.sales,
        where: 'id = ?',
        whereArgs: const <Object?>['sal_legacy_overpay'],
        limit: 1,
      );
      expect(rows, isNotEmpty);
      // paid_amount must have been clamped to total = 1000
      expect(
        (rows.first['paid_amount'] as num?)?.toDouble(),
        closeTo(1000.0, 0.0001),
      );
      await v12Database.close();
    });
  });
}

class _ConsistencyContext {
  _ConsistencyContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        dashboardService = DashboardService(appDatabase: appDatabase),
        salesReportService = SalesReportService(appDatabase: appDatabase),
        profitReportService = ProfitReportService(appDatabase: appDatabase),
        inventoryReportService = InventoryReportService(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final DashboardService dashboardService;
  final SalesReportService salesReportService;
  final ProfitReportService profitReportService;
  final InventoryReportService inventoryReportService;
  final OperationsWorkflowService operationsService;

  static Future<_ConsistencyContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_consistency_',
    );
    return create(rootDirectory);
  }

  static Future<_ConsistencyContext> create(Directory rootDirectory) async {
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _ConsistencyContext._(
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
    final now = DateTime.utc(2026, 5, 16);
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
}

class _MigrationServiceV6 extends MigrationService {
  const _MigrationServiceV6();

  @override
  int get latestVersion => 6;
}

class _MigrationServiceV11 extends MigrationService {
  const _MigrationServiceV11();

  @override
  int get latestVersion => 11;
}

T _expectSuccess<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.asFailure?.error.message,
  );
  return result.asSuccess!.value;
}
