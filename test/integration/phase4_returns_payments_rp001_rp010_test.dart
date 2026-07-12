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
// PHASE 4 — SECTION A: BASIC PAYMENT COLLECTION  (RP-001 … RP-010)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('PHASE 4 Returns & Payments – Section A: Basic Payment Collection', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-001 — Collect payment on unpaid sale
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-001 partial payment updates paid_amount and pending correctly',
        () async {
      final ctx = await _Ctx.fresh('rp001');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp001', qty: 1, cost: 40000, price: 50000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp001',
        price: 50000,
        total: 50000,
      );

      // Collect 20 000
      final collected = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 20000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      expect(collected.newPaidAmount, 20000);
      expect(collected.remainingBalance, 30000);

      // Verify DB state
      final sale = await ctx.readSale(saleId);
      expect(sale['paid_amount'], 20000.0);
      expect((sale['total'] as num) - (sale['paid_amount'] as num), 30000.0);

      // payment row logged
      final payments = await ctx.salePaymentRows(saleId);
      expect(payments, hasLength(1));
      expect((payments.first['amount'] as num).toDouble(), 20000.0);
      expect(payments.first['payment_method'], PaymentMethod.cash);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-002 — Full settlement clears pending and marks as fully paid
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-002 full payment settles sale and zeroes pending', () async {
      final ctx = await _Ctx.fresh('rp002');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp002', qty: 1, cost: 25000, price: 30000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp002',
        price: 30000,
        total: 30000,
      );

      // Partial 20 000
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 20000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // Pay remaining 10 000
      final final_ = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 10000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      expect(final_.newPaidAmount, 30000);
      expect(final_.remainingBalance, 0);

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), 30000);
      expect((sale['paid_amount'] as num).toDouble(), 30000);

      // Attempt one more payment → should fail: already fully paid
      final overflow = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 1,
        paymentMethod: PaymentMethod.cash,
      );
      expect(overflow.isFailure, isTrue);

      // Audit: 2 rows
      expect(await ctx.salePaymentRows(saleId), hasLength(2));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-003 — Multiple incremental collections – running balance exact
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-003 multiple incremental payments maintain exact running balance',
        () async {
      final ctx = await _Ctx.fresh('rp003');
      addTearDown(ctx.dispose);

      const total = 100000.0;
      await ctx.setupAccessory(
          id: 'prd_rp003', qty: 1, cost: 80000, price: total);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp003',
        price: total,
        total: total,
      );

      final payments = [5000.0, 10000.0, 15000.0, 20000.0, 50000.0];
      var expectedPaid = 0.0;

      for (final amt in payments) {
        expectedPaid += amt;
        final r = _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: amt,
            paymentMethod: PaymentMethod.cash,
          ),
        );
        expect(r.newPaidAmount, closeTo(expectedPaid, 0.001));
        expect(r.remainingBalance, closeTo(total - expectedPaid, 0.001));
      }

      final sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), closeTo(total, 0.001));
      expect(await ctx.salePaymentRows(saleId), hasLength(payments.length));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-004 — Overpayment prevention
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-004 overpayment is blocked and never exceeds total', () async {
      final ctx = await _Ctx.fresh('rp004');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp004', qty: 1, cost: 8000, price: 10000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp004',
        price: 10000,
        total: 10000,
      );

      // Remaining = 10 000. Try 15 000.
      final overResult = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 15000,
        paymentMethod: PaymentMethod.cash,
      );
      expect(overResult.isFailure, isTrue,
          reason: 'Overpayment must be rejected');

      // paid_amount must remain 0
      final sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), 0.0);
      expect(await ctx.salePaymentRows(saleId), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-005 — Zero payment rejected
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-005 zero payment is rejected with no audit row', () async {
      final ctx = await _Ctx.fresh('rp005');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp005', qty: 1, cost: 8000, price: 10000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp005',
        price: 10000,
        total: 10000,
      );

      final r = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 0,
        paymentMethod: PaymentMethod.cash,
      );
      expect(r.isFailure, isTrue);
      expect(await ctx.salePaymentRows(saleId), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-006 — Negative payment blocked
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-006 negative payment is blocked', () async {
      final ctx = await _Ctx.fresh('rp006');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp006', qty: 1, cost: 8000, price: 10000);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp006',
        price: 10000,
        total: 10000,
      );

      final r = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: -500,
        paymentMethod: PaymentMethod.cash,
      );
      expect(r.isFailure, isTrue);
      expect(await ctx.salePaymentRows(saleId), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-007 — Decimal payment handled correctly
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-007 decimal payment amounts are handled without rounding error',
        () async {
      final ctx = await _Ctx.fresh('rp007');
      addTearDown(ctx.dispose);

      const total = 999.99;
      await ctx.setupAccessory(
          id: 'prd_rp007', qty: 1, cost: 500.0, price: total);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp007',
        price: total,
        total: total,
      );

      final r = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 333.33,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(r.newPaidAmount, closeTo(333.33, 0.001));
      expect(r.remainingBalance, closeTo(total - 333.33, 0.001));

      // Pay remaining
      final r2 = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: r.remainingBalance,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(r2.remainingBalance, closeTo(0.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-008 — Payment after restart (DB re-opened) – state remains consistent
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-008 payment state persists correctly after database restart',
        () async {
      final dir = await Directory.systemTemp.createTemp('rp008_');
      String saleId;

      // Session 1 – create sale and collect partial payment
      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);
        await ctx.setupAccessory(
            id: 'prd_rp008', qty: 1, cost: 30000, price: 40000);
        saleId = await ctx.sellAccessoryCredit(
          productId: 'prd_rp008',
          price: 40000,
          total: 40000,
        );
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: 15000,
            paymentMethod: PaymentMethod.bank,
          ),
        );
        await db.close();
      }

      // Session 2 – re-open and verify state, then pay remaining
      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);

        final sale = await ctx.readSale(saleId);
        expect((sale['paid_amount'] as num).toDouble(), 15000.0);
        expect((sale['total'] as num).toDouble(), 40000.0);

        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: 25000,
            paymentMethod: PaymentMethod.cash,
          ),
        );

        final saleAfter = await ctx.readSale(saleId);
        expect((saleAfter['paid_amount'] as num).toDouble(), 40000.0);
        expect(await ctx.salePaymentRows(saleId), hasLength(2));

        await db.close();
        await dir.delete(recursive: true);
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-009 — Rapid payment spam – no duplicate collection
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-009 concurrent payment attempts do not exceed sale total',
        () async {
      final ctx = await _Ctx.fresh('rp009');
      addTearDown(ctx.dispose);

      const total = 10000.0;
      await ctx.setupAccessory(
          id: 'prd_rp009', qty: 1, cost: 8000, price: total);
      final saleId = await ctx.sellAccessoryCredit(
        productId: 'prd_rp009',
        price: total,
        total: total,
      );

      // Fire 5 concurrent payments of 10 000 each (only the first should succeed)
      final futures = List.generate(
        5,
        (_) => ctx.ops.collectPayment(
          saleId: saleId,
          amount: total,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      final results = await Future.wait(futures);

      final successes = results.where((r) => r.isSuccess).length;
      expect(successes, 1, reason: 'Only one concurrent payment should win');

      final sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), closeTo(total, 0.001),
          reason: 'paid_amount must not exceed total');
      expect(await ctx.salePaymentRows(saleId), hasLength(1));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-010 — Payment rollback safety – force failure leaves no partial write
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-010 payment on non-existent sale writes nothing to DB', () async {
      final ctx = await _Ctx.fresh('rp010');
      addTearDown(ctx.dispose);

      const phantomSaleId = 'sale_does_not_exist_rp010';

      final r = await ctx.ops.collectPayment(
        saleId: phantomSaleId,
        amount: 5000,
        paymentMethod: PaymentMethod.cash,
      );
      expect(r.isFailure, isTrue);

      // No payment row should have been written
      final rows = await ctx.salePaymentRows(phantomSaleId);
      expect(rows, isEmpty);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
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

  Future<String> createCustomer(String id, String name) async {
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
    return id;
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
}

T _ok<T>(Result<T> result) {
  expect(result.isSuccess, isTrue,
      reason: result.isFailure ? result.asFailure!.error.message : '');
  return result.asSuccess!.value;
}
