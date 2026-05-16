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
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/inventory_report_service.dart';
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

    test('customer balance report groups by customer id and keeps walk-ins',
        () async {
      final context = await _ConsistencyContext.createTemporary();
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
        inventoryReportService = InventoryReportService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final DashboardService dashboardService;
  final SalesReportService salesReportService;
  final ProfitReportService profitReportService;
  final InventoryReportService inventoryReportService;

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

T _expectSuccess<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.asFailure?.error.message,
  );
  return result.asSuccess!.value;
}
