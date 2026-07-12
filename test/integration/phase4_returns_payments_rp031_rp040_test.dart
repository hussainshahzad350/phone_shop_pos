// ignore_for_file: avoid_print

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
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/sales_report_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('PHASE 4 Section F: Financial Correctness', () {
    test('RP-031 daily sales total_sales is reduced after return', () async {
      final ctx = await _Ctx.fresh('rp031');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp031',
        qty: 10,
        cost: 100.0,
        price: 300.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp031',
        qty: 2,
        price: 300.0,
        paid: 600.0,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp031-return',
        ),
      );

      final rows =
          _ok(await ctx.salesService.getDailySalesReport(_allTimeFilter()));
      expect(rows, isNotEmpty);
      expect(rows.first.totalSales, closeTo(300.0, 0.0001));
    });

    test('RP-032 profit report reflects exact net revenue cost and profit',
        () async {
      final ctx = await _Ctx.fresh('rp032');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp032',
        qty: 10,
        cost: 100.0,
        price: 300.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp032',
        qty: 2,
        price: 300.0,
        paid: 600.0,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp032-return',
        ),
      );

      final profit =
          _ok(await ctx.profitService.getProfitReport(_allTimeFilter()));
      expect(profit.totalRevenue, closeTo(300.0, 0.0001));
      expect(profit.totalCost, closeTo(100.0, 0.0001));
      expect(profit.totalProfit, closeTo(200.0, 0.0001));
    });

    test('RP-032A profit rows subtract returned accessory sold quantity',
        () async {
      final ctx = await _Ctx.fresh('rp032a');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp032a',
        qty: 10,
        cost: 200.0,
        price: 500.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp032a',
        qty: 2,
        price: 500.0,
        paid: 1000.0,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp032a-return',
        ),
      );

      final rows = _ok(await ctx.profitService.getProfitReportRows(_allTimeFilter()));
      expect(rows, isNotEmpty);
      expect(rows.first.accessoriesSold, 1);
    });

    test('RP-033 unpaid credit return reduces remaining balance exactly',
        () async {
      final ctx = await _Ctx.fresh('rp033');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp033',
        qty: 10,
        cost: 1000.0,
        price: 1500.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp033',
        qty: 2,
        price: 1500.0,
        paid: 500.0,
        paymentMethod: PaymentMethod.credit,
      );

      final before = await ctx.readSale(saleId);
      expect((before['total'] as num).toDouble(), closeTo(3000.0, 0.001));
      expect((before['paid_amount'] as num).toDouble(), closeTo(500.0, 0.001));

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp033-return',
        ),
      );

      final after = await ctx.readSale(saleId);
      final total = (after['total'] as num).toDouble();
      final paid = (after['paid_amount'] as num).toDouble();
      expect(total, closeTo(1500.0, 0.001));
      expect(paid, closeTo(500.0, 0.001));
      expect(total - paid, closeTo(1000.0, 0.001));
    });

    test('RP-034 fully-paid return clamps paid_amount to adjusted total',
        () async {
      final ctx = await _Ctx.fresh('rp034');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp034',
        qty: 10,
        cost: 100.0,
        price: 300.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp034',
        qty: 2,
        price: 300.0,
        paid: 600.0,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp034-return',
        ),
      );

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(300.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(300.0, 0.001));
    });

    test('RP-035 payment after return cannot exceed adjusted remaining balance',
        () async {
      final ctx = await _Ctx.fresh('rp035');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp035',
        qty: 10,
        cost: 200.0,
        price: 500.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp035',
        qty: 2,
        price: 500.0,
        paid: 200.0,
        paymentMethod: PaymentMethod.credit,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp035-return',
        ),
      );

      final over = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 301.0,
        paymentMethod: PaymentMethod.cash,
      );
      expect(over.isFailure, isTrue);

      final okPayment = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 300.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(okPayment.remainingBalance, closeTo(0.0, 0.001));

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(500.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(500.0, 0.001));
    });

    test('RP-036 return audit rows are append-only across repeated returns',
        () async {
      final ctx = await _Ctx.fresh('rp036');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp036',
        qty: 10,
        cost: 100.0,
        price: 300.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp036',
        qty: 2,
        price: 300.0,
        paid: 600.0,
      );

      final detail1 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail1!.items.first,
          quantity: 1,
          reason: 'first',
        ),
      );

      final rows1 = await ctx.saleReturnRows(saleId);
      expect(rows1, hasLength(1));
      final firstRowSnapshot = Map<String, Object?>.from(rows1.first);

      final detail2 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail2!.items.first,
          quantity: 1,
          reason: 'second',
        ),
      );

      final rows2 = await ctx.saleReturnRows(saleId);
      expect(rows2, hasLength(2));
      expect(rows2.first['id'], firstRowSnapshot['id']);
      expect(rows2.first['return_amount'], firstRowSnapshot['return_amount']);
      expect(rows2.first['created_at'], firstRowSnapshot['created_at']);
    });
  });

  group('PHASE 4 Section G: Edge Cases', () {
    test('RP-037 return after database restart is consistent', () async {
      final dir = await Directory.systemTemp.createTemp('rp037_');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      late String saleId;

      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);

        await ctx.setupAccessory(
          id: 'prd_rp037',
          qty: 10,
          cost: 100.0,
          price: 300.0,
        );
        saleId = await ctx.sellAccessory(
          productId: 'prd_rp037',
          qty: 2,
          price: 300.0,
          paid: 600.0,
        );
        await ctx.appDatabase.close();
      }

      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);

        final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: detail!.items.first,
            quantity: 1,
            reason: 'restart-return',
          ),
        );

        final sale = await ctx.readSale(saleId);
        expect((sale['total'] as num).toDouble(), closeTo(300.0, 0.001));
        expect((sale['paid_amount'] as num).toDouble(), closeTo(300.0, 0.001));
        expect(await ctx.saleReturnRows(saleId), hasLength(1));

        await ctx.appDatabase.close();
      }
    });

    test('RP-038 concurrent return attempts on same IMEI — only one wins',
        () async {
      final ctx = await _Ctx.fresh('rp038');
      addTearDown(ctx.dispose);

      const imei = '356003800380038';
      const phoneId = 'prd_rp038_phone';
      const phonePrice = 50000.0;

      await ctx.setupPhone(
        id: phoneId,
        imei: imei,
        cost: 40000.0,
        price: phonePrice,
      );
      final serializedId = await ctx.getSerializedStockId(imei);
      final saleId = await ctx.sellPhone(
        productId: phoneId,
        serializedStockId: serializedId,
        imei: imei,
        price: phonePrice,
        paid: phonePrice,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      final futures = List.generate(
        5,
        (_) => ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'concurrent',
        ),
      );
      final results = await Future.wait(futures);

      final successes = results.where((r) => r.isSuccess).length;
      expect(successes, 1,
          reason: 'Exactly one concurrent IMEI return should win');

      final returnRows = await ctx.saleReturnRows(saleId);
      expect(returnRows, hasLength(1));

      final ssRows = await ctx.appDatabase.queryTable(
        TableNames.serializedStock,
        where: 'id = ?',
        whereArgs: <Object?>[serializedId],
        limit: 1,
      );
      expect(ssRows.single['stock_status'], equals('in_stock'));
    });

    test('RP-039 return with phantom saleItemId is blocked safely', () async {
      final ctx = await _Ctx.fresh('rp039');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp039',
        qty: 5,
        cost: 3000.0,
        price: 5000.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp039',
        qty: 1,
        price: 5000.0,
        paid: 5000.0,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final realItem = detail!.items.first;

      const phantomItem = SalesInvoiceItemEntity(
        saleItemId: 'si_phantom_rp039_does_not_exist',
        productModelId: 'prd_rp039',
        productName: 'phantom',
        hasImei: false,
        quantity: 1,
        unitPrice: 5000.0,
        lineTotal: 5000.0,
        serializedStockId: null,
        imei: null,
        returnedQty: 0,
      );

      final r = await ctx.ops.processReturn(
        saleId: saleId,
        item: phantomItem,
        quantity: 1,
        reason: 'phantom-item-return',
      );
      expect(r.isFailure, isTrue);

      final saleAfter = await ctx.readSale(saleId);
      expect((saleAfter['total'] as num).toDouble(), closeTo(5000.0, 0.001));
      expect(await ctx.saleReturnRows(saleId), isEmpty);
      expect(realItem.returnableQty, 1);
    });

    test('RP-040 return on fully-returned item is rejected', () async {
      final ctx = await _Ctx.fresh('rp040');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
        id: 'prd_rp040',
        qty: 5,
        cost: 3000.0,
        price: 5000.0,
      );
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp040',
        qty: 1,
        price: 5000.0,
        paid: 5000.0,
      );

      final detail1 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail1!.items.first,
          quantity: 1,
          reason: 'first-return',
        ),
      );

      final detail2 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final r = await ctx.ops.processReturn(
        saleId: saleId,
        item: detail2!.items.first,
        quantity: 1,
        reason: 'second-return',
      );
      expect(r.isFailure, isTrue);

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect(await ctx.saleReturnRows(saleId), hasLength(1));
    });
  });
}

ReportFilterEntity _allTimeFilter() {
  return ReportFilterEntity(
    startDate: DateTime.utc(2000, 1, 1),
    endDate: DateTime.utc(2100, 1, 1),
    pageSize: 200,
  );
}

AppDatabase _makeDb(Directory dir) {
  return AppDatabase(
    localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
    migrationService: const MigrationService(),
  );
}

class _Ctx {
  _Ctx({required Directory dir, required this.appDatabase})
      : _dir = dir,
        ops = OperationsWorkflowService(appDatabase: appDatabase),
        profitService = ProfitReportService(appDatabase: appDatabase),
        salesService = SalesReportService(appDatabase: appDatabase),
        _products = SqliteProductRepository(appDatabase: appDatabase),
        _purchases = SqlitePurchaseRepository(appDatabase: appDatabase),
        _sales = SqliteSalesRepository(appDatabase: appDatabase);

  final Directory _dir;
  final AppDatabase appDatabase;
  final OperationsWorkflowService ops;
  final ProfitReportService profitService;
  final SalesReportService salesService;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository _sales;

  static Future<_Ctx> fresh(String tag) async {
    final dir = await Directory.systemTemp.createTemp('phone_shop_pos_${tag}_');
    final db = _makeDb(dir);
    await db.initialize(seedDemoData: false);
    return _Ctx(dir: dir, appDatabase: db);
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
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

  Future<String> getSerializedStockId(String imei) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'imei1 = ?',
      whereArgs: <Object?>[imei],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single['id'] as String;
  }

  Future<String> sellPhone({
    required String productId,
    required String serializedStockId,
    required String imei,
    required double price,
    required double paid,
    String paymentMethod = PaymentMethod.cash,
  }) async {
    final completion = _ok(
      await _sales.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productId,
            productName: 'Phone $productId',
            hasImei: true,
            quantity: 1,
            unitPrice: price,
            serializedStockId: serializedStockId,
            imei: imei,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: price,
          discount: 0,
          tax: 0,
          total: price,
          paidAmount: paid,
        ),
        paymentMethod: paymentMethod,
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }

  Future<String> sellAccessory({
    required String productId,
    required int qty,
    required double price,
    required double paid,
    String paymentMethod = PaymentMethod.cash,
  }) async {
    final total = price * qty;
    final completion = _ok(
      await _sales.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productId,
            productName: 'Product $productId',
            hasImei: false,
            quantity: qty,
            unitPrice: price,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: total,
          discount: 0,
          tax: 0,
          total: total,
          paidAmount: paid,
        ),
        paymentMethod: paymentMethod,
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }

  Future<Map<String, Object?>> readSale(String saleId) async {
    final rows = await appDatabase.queryTable(
      TableNames.sales,
      where: 'id = ?',
      whereArgs: <Object?>[saleId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<List<Map<String, Object?>>> saleReturnRows(String saleId) async {
    return appDatabase.database.rawQuery(
      'SELECT * FROM ${TableNames.saleReturns} WHERE sale_id = ? ORDER BY created_at ASC',
      <Object?>[saleId],
    );
  }

  Future<List<Map<String, Object?>>> salePaymentRows(String saleId) async {
    return appDatabase.database.rawQuery(
      'SELECT * FROM ${TableNames.salePayments} WHERE sale_id = ? ORDER BY created_at ASC',
      <Object?>[saleId],
    );
  }
}

T _ok<T>(Result<T> result) {
  expect(result.isSuccess, isTrue,
      reason: result.isFailure ? result.asFailure!.error.message : '');
  return result.asSuccess!.value;
}
