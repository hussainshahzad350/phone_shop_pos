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
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('PHASE 2 Purchases P-031..P-040', () {
    test('P-031 Large purchase history remains usable (50+ entries)', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      for (var index = 0; index < 60; index++) {
        await context.insertManualPurchase(
          id: 'pur_p031_$index',
          purchaseDateUtc: DateTime.utc(2026, 5, 1).add(Duration(hours: index)),
          total: (100 + index).toDouble(),
        );
      }

      final stopwatch = Stopwatch()..start();
      final rows = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: null,
          endDate: null,
          limit: 100,
          offset: 0,
        ),
      );
      stopwatch.stop();

      expect(rows.length, 60);
      expect(stopwatch.elapsedMilliseconds, lessThan(2500));
    });

    test('P-032 Pagination keeps older entries accessible', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      for (var index = 0; index < 55; index++) {
        await context.insertManualPurchase(
          id: 'pur_p032_${index.toString().padLeft(2, '0')}',
          purchaseDateUtc: DateTime.utc(2026, 5, 1).add(Duration(days: index)),
          total: (200 + index).toDouble(),
        );
      }

      final page1 = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: null,
          endDate: null,
          limit: 20,
          offset: 0,
        ),
      );
      final page2 = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: null,
          endDate: null,
          limit: 20,
          offset: 20,
        ),
      );
      final page3 = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: null,
          endDate: null,
          limit: 20,
          offset: 40,
        ),
      );

      expect(page1.length, 20);
      expect(page2.length, 20);
      expect(page3.length, 15);

      final allIds = <String>{
        ...page1.map((row) => row.purchaseId),
        ...page2.map((row) => row.purchaseId),
        ...page3.map((row) => row.purchaseId),
      };
      expect(allIds.length, 55);
      expect(allIds.contains('pur_p032_00'), isTrue);
      expect(allIds.contains('pur_p032_54'), isTrue);
    });

    test('P-033 Purchase math matches manual subtotal', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p033_a',
        name: 'P033 Item A',
        sku: 'P033-A',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_p033_b',
        name: 'P033 Item B',
        sku: 'P033-B',
        purchasePrice: 50,
        salePrice: 90,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p033_a',
              productName: 'P033 Item A',
              hasImei: false,
              quantity: 3,
              unitCost: 100,
            ),
            PurchaseFormItem(
              productModelId: 'prd_p033_b',
              productName: 'P033 Item B',
              hasImei: false,
              quantity: 2,
              unitCost: 50,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 400,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      expect((purchase['subtotal'] as num).toDouble(), closeTo(400, 0.0001));
      expect((purchase['total'] as num).toDouble(), closeTo(400, 0.0001));
    });

    test('P-034 Purchase updates inventory valuation correctly', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p034_acc',
        name: 'P034 Accessory',
        sku: 'P034-ACC-001',
        purchasePrice: 100,
        salePrice: 170,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p034_acc',
              productName: 'P034 Accessory',
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
              productModelId: 'prd_p034_acc',
              productName: 'P034 Accessory',
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

      final stock = await context.fetchInventoryStock('prd_p034_acc');
      expect(stock['quantity'], 20);
      expect((stock['unit_cost'] as num).toDouble(), closeTo(150, 0.0001));
    });

    test('P-035 Future sale profit uses updated cost snapshot', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      final nowUtc = DateTimeHelpers.nowUtc();
      final filter = ReportFilterEntity(
        startDate: DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day),
        endDate: DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day),
      );

      await context.createProduct(
        id: 'prd_p035_acc',
        name: 'P035 Accessory',
        sku: 'P035-ACC-001',
        purchasePrice: 100,
        salePrice: 250,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p035_acc',
              productName: 'P035 Accessory',
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
              productModelId: 'prd_p035_acc',
              productName: 'P035 Accessory',
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
              productModelId: 'prd_p035_acc',
              productName: 'P035 Accessory',
              hasImei: false,
              quantity: 1,
              unitPrice: 250,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 250,
            discount: 0,
            tax: 0,
            total: 250,
            paidAmount: 250,
          ),
          saleDate: nowUtc,
        ),
      );

      final profit = _expectSuccess(
          await context.profitReportService.getProfitReport(filter));
      expect(profit.totalProfit, closeTo(100, 0.0001));
    });

    test('P-036 Purchase with tax/discount computes totals correctly',
        () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p036_acc',
        name: 'P036 Accessory',
        sku: 'P036-ACC-001',
        purchasePrice: 100,
        salePrice: 140,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p036_acc',
              productName: 'P036 Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 100,
            ),
          ],
          discount: 100,
          tax: 50,
          paidAmount: 950,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      expect((purchase['subtotal'] as num).toDouble(), closeTo(1000, 0.0001));
      expect((purchase['discount'] as num).toDouble(), closeTo(100, 0.0001));
      expect((purchase['tax'] as num).toDouble(), closeTo(50, 0.0001));
      expect((purchase['total'] as num).toDouble(), closeTo(950, 0.0001));
    });

    test('P-037 Product search remains fast and accurate', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      for (var index = 0; index < 250; index++) {
        await context.createProduct(
          id: 'prd_p037_$index',
          name: 'P037 Product $index',
          sku: 'P037-$index',
          purchasePrice: (100 + index).toDouble(),
          salePrice: (200 + index).toDouble(),
          hasImei: false,
        );
      }

      final stopwatch = Stopwatch()..start();
      final result = await context.purchaseRepository.searchProducts(
        'P037',
        limit: 30,
      );
      stopwatch.stop();

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess!.value, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('P-040 Long-session style repeated usage stays stable', () async {
      final context = await _P2CContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p040_acc',
        name: 'P040 Accessory',
        sku: 'P040-ACC-001',
        purchasePrice: 80,
        salePrice: 140,
        hasImei: false,
      );

      for (var index = 0; index < 25; index++) {
        _expectSuccess(
          await context.purchaseRepository.createPurchaseTransaction(
            items: const <PurchaseFormItem>[
              PurchaseFormItem(
                productModelId: 'prd_p040_acc',
                productName: 'P040 Accessory',
                hasImei: false,
                quantity: 1,
                unitCost: 80,
              ),
            ],
            discount: 0,
            tax: 0,
            paidAmount: 80,
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      for (var index = 0; index < 200; index++) {
        final products =
            await context.purchaseRepository.searchProducts('P040', limit: 30);
        expect(products.isSuccess, isTrue);

        final history = await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: null,
          endDate: null,
          limit: 50,
          offset: 0,
        );
        expect(history.isSuccess, isTrue);
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(12000));
    });
  });
}

class _P2CContext {
  _P2CContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase),
        profitReportService = ProfitReportService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final OperationsWorkflowService operationsService;
  final ProfitReportService profitReportService;

  static Future<_P2CContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase2_p031_p040_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService:
          SqliteFfiDatabaseService(rootDirectory: rootDirectory.path),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _P2CContext._(
        rootDirectory: rootDirectory, appDatabase: appDatabase);
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

  Future<void> insertManualPurchase({
    required String id,
    required DateTime purchaseDateUtc,
    required double total,
  }) async {
    final timestamp = DateTimeHelpers.toSql(purchaseDateUtc);
    await appDatabase.insert(TableNames.purchases, <String, Object?>{
      'id': id,
      'supplier_id': null,
      'invoice_number': 'INV-$id',
      'purchase_date': timestamp,
      'subtotal': total,
      'discount': 0,
      'tax': 0,
      'total': total,
      'paid_amount': total,
      'notes': null,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }

  Future<Map<String, Object?>> fetchPurchase(String purchaseId) async {
    final rows = await appDatabase.queryTable(
      TableNames.purchases,
      where: 'id = ?',
      whereArgs: <Object?>[purchaseId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<Map<String, Object?>> fetchInventoryStock(
      String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
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
