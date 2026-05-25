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
import 'package:phone_shop_pos/modules/customers/data/repositories/sqlite_customer_repository.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 4 — SECTION B: PAYMENT HISTORY / LEDGER  (RP-011 … RP-015)
// PHASE 4 — SECTION C: FULL RETURNS (PHONES)      (RP-016 … RP-020)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION B
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section B: Payment History / Ledger', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-011 — sale_payments audit row created with correct schema
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-011 sale_payments row has all required fields after collection',
        () async {
      final ctx = await _Ctx.fresh('rp011');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp011', qty: 1, cost: 8000, price: 10000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp011',
        price: 10000,
        total: 10000,
      );

      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 10000,
          paymentMethod: PaymentMethod.bank,
          notes: 'Bank transfer receipt #123',
        ),
      );

      final rows = await ctx.salePaymentRows(saleId);
      expect(rows, hasLength(1));
      final row = rows.first;

      expect(row['id'], isNotNull);
      expect(row['sale_id'], saleId);
      expect((row['amount'] as num).toDouble(), 10000.0);
      expect(row['payment_method'], PaymentMethod.bank);
      expect(row['notes'], 'Bank transfer receipt #123');
      expect(row['created_at'], isNotNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-012 — Multiple payment history rows are timestamp-ordered
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-012 multiple payment rows are ordered by created_at ascending',
        () async {
      final ctx = await _Ctx.fresh('rp012');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp012', qty: 1, cost: 8000, price: 30000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp012',
        price: 30000,
        total: 30000,
      );

      for (final amt in [5000.0, 10000.0, 15000.0]) {
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: amt,
            paymentMethod: PaymentMethod.cash,
          ),
        );
      }

      final rows = await ctx.salePaymentRows(saleId);
      expect(rows, hasLength(3));

      // Assert ascending timestamp ordering
      for (var i = 0; i < rows.length - 1; i++) {
        final t1 = rows[i]['created_at'] as String;
        final t2 = rows[i + 1]['created_at'] as String;
        expect(t1.compareTo(t2), lessThanOrEqualTo(0));
      }

      // Verify cumulative amounts
      final amounts = rows.map((r) => (r['amount'] as num).toDouble()).toList();
      expect(amounts, containsAllInOrder([5000.0, 10000.0, 15000.0]));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-013 — Customer receivable reduces precisely after payment
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-013 customer pending balance reduces exactly after payment',
        () async {
      final ctx = await _Ctx.fresh('rp013');
      addTearDown(ctx.dispose);

      await ctx.createCustomer('cust_rp013', 'RP013 Customer');
      await ctx.setupAccessory(
          id: 'prd_rp013', qty: 1, cost: 8000, price: 50000);

      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp013',
        price: 50000,
        total: 50000,
        customerId: 'cust_rp013',
      );

      // Verify pending = 50 000
      var sale = await ctx.readSale(saleId);
      expect(
        (sale['total'] as num) - (sale['paid_amount'] as num),
        50000.0,
      );

      // Collect 20 000
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 20000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), 20000.0);
      expect((sale['total'] as num) - (sale['paid_amount'] as num), 30000.0);

      // Collect remaining
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 30000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), 50000.0);
      expect((sale['total'] as num) - (sale['paid_amount'] as num), 0.0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-014 — Same-name customers are grouped by customer_id, not name
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-014 same-name customers kept isolated by customer_id', () async {
      final ctx = await _Ctx.fresh('rp014');
      addTearDown(ctx.dispose);

      await ctx.createCustomer('cust_rp014_a', 'Ali Khan');
      await ctx.createCustomer('cust_rp014_b', 'Ali Khan'); // same name

      await ctx.setupAccessory(
          id: 'prd_rp014', qty: 2, cost: 8000, price: 10000);

      final saleA = await ctx.sellAccessoryCredit(
        productId: 'prd_rp014',
        price: 10000,
        total: 10000,
        customerId: 'cust_rp014_a',
      );
      final saleB = await ctx.sellAccessoryCredit(
        productId: 'prd_rp014',
        price: 10000,
        total: 10000,
        customerId: 'cust_rp014_b',
      );

      // Pay only A
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleA,
          amount: 10000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // A should be fully paid, B still pending
      final rowA = await ctx.readSale(saleA);
      final rowB = await ctx.readSale(saleB);
      expect((rowA['paid_amount'] as num).toDouble(), 10000.0);
      expect((rowB['paid_amount'] as num).toDouble(), 0.0);

      // Verify customer_id isolation in sale rows
      expect(rowA['customer_id'], 'cust_rp014_a');
      expect(rowB['customer_id'], 'cust_rp014_b');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-015 — Search unpaid invoices returns correct filtered list
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-015 pendingOnly filter returns only unpaid credit invoices',
        () async {
      final ctx = await _Ctx.fresh('rp015');
      addTearDown(ctx.dispose);

      await ctx.createCustomer('cust_rp015', 'Test Customer');
      await ctx.setupAccessory(
          id: 'prd_rp015', qty: 3, cost: 8000, price: 10000);

      // Sale 1: credit unpaid
      await ctx.sellAccessoryCredit(
        productId: 'prd_rp015',
        price: 10000,
        total: 10000,
        customerId: 'cust_rp015',
      );

      // Sale 2: credit paid immediately
      final saleB = await ctx.sellAccessoryCredit(
        productId: 'prd_rp015',
        price: 10000,
        total: 10000,
        customerId: 'cust_rp015',
      );
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleB,
          amount: 10000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // Cash sale (should never appear in pending list)
      _ok(
        await ctx.ops.searchSalesHistory(
          invoiceQuery: '',
          customerQuery: '',
          startDate: null,
          endDate: null,
          pendingOnly: false,
        ),
      );

      final pendingList = _ok(
        await ctx.ops.searchSalesHistory(
          invoiceQuery: '',
          customerQuery: '',
          startDate: null,
          endDate: null,
          pendingOnly: true,
          collectibleOnly: true,
        ),
      );

      // Only sale A should be in pending list
      expect(pendingList, hasLength(1));
      expect(pendingList.first.remainingBalance, 10000.0);
      expect(pendingList.first.customerId, 'cust_rp015');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION C — FULL RETURNS (PHONES)
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section C: Full IMEI Returns', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-016 — Full IMEI return on fully-paid sale
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-016 full phone return restores IMEI and reverses financials',
        () async {
      final ctx = await _Ctx.fresh('rp016');
      addTearDown(ctx.dispose);

      const imei = '356001016000160';
      await ctx.setupPhone(
          id: 'prd_rp016', imei: imei, cost: 40000, price: 50000);
      final serializedId = await ctx.getSerializedStockId(imei);

      final saleId = await ctx.sellPhone(
        productId: 'prd_rp016',
        serializedStockId: serializedId,
        imei: imei,
        price: 50000,
        paid: 50000, // fully paid
      );

      // Verify IMEI is sold
      expect(await ctx.getImeiStatus(serializedId), 'sold');

      // Fetch invoice for item reference
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'defective',
        ),
      );

      // IMEI restored to in_stock
      expect(await ctx.getImeiStatus(serializedId), 'in_stock');

      // Financial adjustment: total reduced, paid clamped
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));

      // Return audit row exists
      final returnRows = await ctx.saleReturnRows(saleId);
      expect(returnRows, isNotEmpty);
      expect(returnRows.first['serialized_stock_id'], serializedId);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-017 — Full IMEI return on partial-payment sale
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-017 phone return on partial-pay sale corrects pending balance',
        () async {
      final ctx = await _Ctx.fresh('rp017');
      addTearDown(ctx.dispose);

      const imei = '356001017000170';
      await ctx.setupPhone(
          id: 'prd_rp017', imei: imei, cost: 40000, price: 60000);
      final serializedId = await ctx.getSerializedStockId(imei);

      final saleId = await ctx.sellPhone(
        productId: 'prd_rp017',
        serializedStockId: serializedId,
        imei: imei,
        price: 60000,
        paid: 0, // credit
        paymentMethod: PaymentMethod.credit,
      );

      // Collect 20 000
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 20000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'returned by customer',
        ),
      );

      // total becomes 0, paid clamped to 0, no ghost receivable
      final sale = await ctx.readSale(saleId);
      final total = (sale['total'] as num).toDouble();
      final paid = (sale['paid_amount'] as num).toDouble();
      expect(total, closeTo(0.0, 0.001));
      expect(paid, closeTo(0.0, 0.001));
      // pending must not be negative
      expect((total - paid).clamp(0.0, double.infinity), closeTo(0.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-018 — Full IMEI return on completely unpaid sale
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-018 phone return on unpaid sale removes entire receivable',
        () async {
      final ctx = await _Ctx.fresh('rp018');
      addTearDown(ctx.dispose);

      const imei = '356001018000180';
      await ctx.setupPhone(
          id: 'prd_rp018', imei: imei, cost: 40000, price: 50000);
      final serializedId = await ctx.getSerializedStockId(imei);

      final saleId = await ctx.sellPhone(
        productId: 'prd_rp018',
        serializedStockId: serializedId,
        imei: imei,
        price: 50000,
        paid: 0,
        paymentMethod: PaymentMethod.credit,
      );

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'wrong phone',
        ),
      );

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-019 — Double return prevention
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-019 second return of same IMEI is blocked', () async {
      final ctx = await _Ctx.fresh('rp019');
      addTearDown(ctx.dispose);

      const imei = '356001019000190';
      await ctx.setupPhone(
          id: 'prd_rp019', imei: imei, cost: 40000, price: 50000);
      final serializedId = await ctx.getSerializedStockId(imei);

      final saleId = await ctx.sellPhone(
        productId: 'prd_rp019',
        serializedStockId: serializedId,
        imei: imei,
        price: 50000,
        paid: 50000,
      );

      // First return – succeeds
      final detail1 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail1!.items.first,
          quantity: 1,
          reason: 'first return',
        ),
      );

      // Second return – must fail (returnableQty == 0)
      final detail2 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item2 = detail2!.items.first;
      expect(item2.returnableQty, 0,
          reason: 'returnableQty must be 0 after full return');

      final r2 = await ctx.ops.processReturn(
        saleId: saleId,
        item: item2,
        quantity: 1,
        reason: 'duplicate return attempt',
      );
      expect(r2.isFailure, isTrue);

      // Exactly one return row
      expect(await ctx.saleReturnRows(saleId), hasLength(1));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-020 — Returned IMEI is restored exactly once in serialized_stock
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-020 IMEI restored to in_stock exactly once with integrity',
        () async {
      final ctx = await _Ctx.fresh('rp020');
      addTearDown(ctx.dispose);

      const imei = '356001020000200';
      await ctx.setupPhone(
          id: 'prd_rp020', imei: imei, cost: 40000, price: 50000);
      final serializedId = await ctx.getSerializedStockId(imei);

      final saleId = await ctx.sellPhone(
        productId: 'prd_rp020',
        serializedStockId: serializedId,
        imei: imei,
        price: 50000,
        paid: 50000,
      );

      expect(await ctx.getImeiStatus(serializedId), 'sold');

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'quality issue',
        ),
      );

      // Status is in_stock
      expect(await ctx.getImeiStatus(serializedId), 'in_stock');

      // Exactly one device row with that IMEI (no duplicate created)
      final count = await ctx.appDatabase.database.rawQuery(
        'SELECT COUNT(*) AS c FROM ${TableNames.serializedStock} WHERE imei1 = ?',
        <Object?>[imei],
      );
      expect((count.first['c'] as num).toInt(), 1);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (self-contained)
// ─────────────────────────────────────────────────────────────────────────────

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
        _products = SqliteProductRepository(appDatabase: appDatabase),
        _purchases = SqlitePurchaseRepository(appDatabase: appDatabase),
        _sales = SqliteSalesRepository(appDatabase: appDatabase),
        _customers = SqliteCustomerRepository(appDatabase: appDatabase);

  final Directory _dir;
  final AppDatabase appDatabase;
  final OperationsWorkflowService ops;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository _sales;
  final SqliteCustomerRepository _customers;

  static Future<_Ctx> fresh(String tag) async {
    final dir = await Directory.systemTemp.createTemp('phone_shop_pos_${tag}_');
    final db = _makeDb(dir);
    await db.initialize(seedDemoData: false);
    return _Ctx(dir: dir, appDatabase: db);
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await _dir.exists()) await _dir.delete(recursive: true);
  }

  Future<void> createCustomer(String id, String name) async {
    final now = DateTimeHelpers.nowUtc();
    _ok(
      await _customers.createCustomer(
        CustomerEntity(
          id: id,
          name: name,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
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

  Future<String> sellAccessoryCredit({
    required String productId,
    required double price,
    required double total,
    String? customerId,
  }) async {
    final completion = _ok(
      await _sales.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: productId,
            productName: 'Product $productId',
            hasImei: false,
            quantity: 1,
            unitPrice: price,
          ),
        ],
        totals: SaleTotalsEntity(
          subtotal: total,
          discount: 0,
          tax: 0,
          total: total,
          paidAmount: 0,
        ),
        customerId: customerId,
        paymentMethod: PaymentMethod.credit,
        saleDate: DateTimeHelpers.nowUtc(),
      ),
    );
    return completion.saleId;
  }

  Future<String> sellPhone({
    required String productId,
    required String serializedStockId,
    required String imei,
    required double price,
    required double paid,
    String paymentMethod = PaymentMethod.cash,
    String? customerId,
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
        customerId: customerId,
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
    expect(rows, isNotEmpty, reason: 'Sale $saleId not found');
    return rows.single;
  }

  Future<List<Map<String, Object?>>> salePaymentRows(String saleId) async {
    return appDatabase.database.rawQuery(
      'SELECT * FROM ${TableNames.salePayments} WHERE sale_id = ? ORDER BY created_at ASC',
      <Object?>[saleId],
    );
  }

  Future<List<Map<String, Object?>>> saleReturnRows(String saleId) async {
    return appDatabase.database.rawQuery(
      'SELECT * FROM ${TableNames.saleReturns} WHERE sale_id = ? ORDER BY created_at ASC',
      <Object?>[saleId],
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
}

T _ok<T>(Result<T> result) {
  expect(result.isSuccess, isTrue,
      reason: result.isFailure ? result.asFailure!.error.message : '');
  return result.asSuccess!.value;
}
