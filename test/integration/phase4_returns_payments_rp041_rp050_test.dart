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
// PHASE 4 — SECTION H: LONG / COMPLEX FLOWS       (RP-041 … RP-045)
// PHASE 4 — SECTION I: EXTREME FINANCIAL INVARIANTS (RP-046 … RP-050)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION H — LONG / COMPLEX FLOWS
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section H: Long / Complex Flows', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-041 — Long receivable lifecycle: partial sale → many collections
    //          → partial return → exact final balance
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-041 long receivable lifecycle maintains exact balance throughout',
        () async {
      final ctx = await _Ctx.fresh('rp041');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp041', qty: 10, cost: 8000.0, price: 10000.0);

      // Credit sale: 5 units @ 10000 = 50000, paid=0
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp041',
        qty: 5,
        price: 10000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Verify initial pending = 50000
      var sale = await ctx.readSale(saleId);
      _assertSaleInvariant(sale);
      expect(
          (sale['total'] as num).toDouble() -
              (sale['paid_amount'] as num).toDouble(),
          closeTo(50000.0, 0.001));

      // Collect payments: 5000, 10000, 8000
      for (final amt in [5000.0, 10000.0, 8000.0]) {
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: amt,
            paymentMethod: PaymentMethod.cash,
          ),
        );
        sale = await ctx.readSale(saleId);
        _assertSaleInvariant(sale);
      }

      // paid = 23000, pending = 27000
      sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), closeTo(23000.0, 0.001));
      expect(
        (sale['total'] as num).toDouble() -
            (sale['paid_amount'] as num).toDouble(),
        closeTo(27000.0, 0.001),
      );

      // Return 2 units (total reduced by 20000, paid clamped to min(23000, 30000)=23000)
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 2,
          reason: 'partial-return',
        ),
      );
      sale = await ctx.readSale(saleId);
      _assertSaleInvariant(sale);

      // total = 50000-20000=30000, paid=23000, pending=7000
      expect((sale['total'] as num).toDouble(), closeTo(30000.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(23000.0, 0.001));
      expect(
        (sale['total'] as num).toDouble() -
            (sale['paid_amount'] as num).toDouble(),
        closeTo(7000.0, 0.001),
      );

      // Collect remaining 7000
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 7000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      sale = await ctx.readSale(saleId);
      _assertSaleInvariant(sale);
      expect((sale['paid_amount'] as num).toDouble(), closeTo(30000.0, 0.001));

      // Now fully paid – further payment blocked
      final blocked = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 1,
        paymentMethod: PaymentMethod.cash,
      );
      expect(blocked.isFailure, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-042 — 10-payment sequence: no rounding drift
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-042 ten incremental payments sum to exact total without drift',
        () async {
      final ctx = await _Ctx.fresh('rp042');
      addTearDown(ctx.dispose);

      const total = 99999.90;
      await ctx.setupAccessory(
          id: 'prd_rp042', qty: 1, cost: 50000.0, price: total);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp042',
        qty: 1,
        price: total,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // 9 equal payments of 9999.99, then a final clean-up payment
      var remaining = total;
      for (var i = 0; i < 9; i++) {
        const chunk = 9999.99;
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: chunk,
            paymentMethod: PaymentMethod.cash,
          ),
        );
        remaining -= chunk;
        final sale = await ctx.readSale(saleId);
        _assertSaleInvariant(sale);
      }

      // Final precise remaining payment
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: remaining,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final sale = await ctx.readSale(saleId);
      expect((sale['paid_amount'] as num).toDouble(), closeTo(total, 0.001));
      _assertSaleInvariant(sale);

      // 10 payment rows
      final paymentRows = await ctx.salePaymentRows(saleId);
      expect(paymentRows, hasLength(10));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-043 — Mixed customer receivables are isolated correctly
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-043 two customers receivables are fully isolated', () async {
      final ctx = await _Ctx.fresh('rp043');
      addTearDown(ctx.dispose);

      await ctx.createCustomer('cust_rp043_a', 'Customer A');
      await ctx.createCustomer('cust_rp043_b', 'Customer B');

      await ctx.setupAccessory(
          id: 'prd_rp043', qty: 10, cost: 3000.0, price: 5000.0);

      // Customer A: 3 units credit = 15000
      final saleA = await ctx.sellAccessory(
        productId: 'prd_rp043',
        qty: 3,
        price: 5000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
        customerId: 'cust_rp043_a',
      );

      // Customer B: 2 units credit = 10000
      final saleB = await ctx.sellAccessory(
        productId: 'prd_rp043',
        qty: 2,
        price: 5000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
        customerId: 'cust_rp043_b',
      );

      // Collect 8000 from A only
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleA,
          amount: 8000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // Return 1 from B only
      final detailB = _ok(await ctx.ops.getSalesInvoiceDetail(saleB));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleB,
          item: detailB!.items.first,
          quantity: 1,
          reason: 'return-b',
        ),
      );

      final rowA = await ctx.readSale(saleA);
      final rowB = await ctx.readSale(saleB);

      // A: total=15000, paid=8000, pending=7000 (unaffected by B)
      expect((rowA['total'] as num).toDouble(), closeTo(15000.0, 0.001));
      expect((rowA['paid_amount'] as num).toDouble(), closeTo(8000.0, 0.001));

      // B: total=5000 (10000-5000 returned), paid=0
      expect((rowB['total'] as num).toDouble(), closeTo(5000.0, 0.001));
      expect((rowB['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));

      _assertSaleInvariant(rowA);
      _assertSaleInvariant(rowB);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-044 — Stress return loop: 20 individual accessory items returned
    //          one by one; invariant preserved throughout
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-044 stress loop of 20 sequential returns maintains invariant',
        () async {
      final ctx = await _Ctx.fresh('rp044');
      addTearDown(ctx.dispose);

      const unitPrice = 1000.0;
      const qty = 20;
      const total = unitPrice * qty; // 20000

      await ctx.setupAccessory(
          id: 'prd_rp044', qty: qty, cost: 500.0, price: unitPrice);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp044',
        qty: qty,
        price: unitPrice,
        paid: total,
      );

      for (var i = 0; i < qty; i++) {
        final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
        final item = detail!.items.first;
        expect(item.returnableQty, qty - i);

        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: item,
            quantity: 1,
            reason: 'loop-return-$i',
          ),
        );

        final sale = await ctx.readSale(saleId);
        _assertSaleInvariant(sale);
        final expectedTotal = total - (unitPrice * (i + 1));
        expect(
            (sale['total'] as num).toDouble(), closeTo(expectedTotal, 0.001));
      }

      // All returned
      final finalSale = await ctx.readSale(saleId);
      expect((finalSale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect((finalSale['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));
      expect(await ctx.saleReturnRows(saleId), hasLength(qty));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-045 — Restart after multiple returns/payments: durable persistence
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-045 multiple returns and payments survive database restart',
        () async {
      final dir = await Directory.systemTemp.createTemp('rp045_');
      String saleId;

      // Session 1 – create, pay, return
      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);
        await ctx.setupAccessory(
            id: 'prd_rp045', qty: 10, cost: 3000.0, price: 5000.0);
        saleId = await ctx.sellAccessory(
          productId: 'prd_rp045',
          qty: 5,
          price: 5000.0,
          paid: 0.0,
          paymentMethod: PaymentMethod.credit,
        );

        // Collect 10000
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: 10000,
            paymentMethod: PaymentMethod.cash,
          ),
        );

        // Return 2 units individually (2 separate calls → 2 audit rows)
        for (var i = 0; i < 2; i++) {
          final det = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
          _ok(
            await ctx.ops.processReturn(
              saleId: saleId,
              item: det!.items.first,
              quantity: 1,
              reason: 'pre-restart-return-$i',
            ),
          );
        }

        await db.close();
      }

      // Session 2 – verify everything persisted
      {
        final db = _makeDb(dir);
        await db.initialize(seedDemoData: false);
        final ctx = _Ctx(dir: dir, appDatabase: db);

        final sale = await ctx.readSale(saleId);
        // total = 25000-10000=15000, paid=10000, pending=5000
        expect((sale['total'] as num).toDouble(), closeTo(15000.0, 0.001));
        expect(
            (sale['paid_amount'] as num).toDouble(), closeTo(10000.0, 0.001));
        _assertSaleInvariant(sale);

        // Return rows  (2 individual single-unit returns from session 1)
        final returnRows = await ctx.saleReturnRows(saleId);
        expect(returnRows, hasLength(2));

        // Payment rows (1 from session 1)
        final paymentRows = await ctx.salePaymentRows(saleId);
        expect(paymentRows, hasLength(1));

        // Collect remaining 5000 in session 2
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: 5000,
            paymentMethod: PaymentMethod.cash,
          ),
        );

        final finalSale = await ctx.readSale(saleId);
        expect((finalSale['paid_amount'] as num).toDouble(),
            closeTo(15000.0, 0.001));

        await db.close();
        await dir.delete(recursive: true);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION I — EXTREME FINANCIAL INVARIANTS
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section I: Extreme Financial Invariants', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-046 — paid_amount never exceeds total in any state
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-046 paid_amount never exceeds total after all operations',
        () async {
      final ctx = await _Ctx.fresh('rp046');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp046', qty: 10, cost: 3000.0, price: 5000.0);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp046',
        qty: 4,
        price: 5000.0,
        paid: 20000.0,
      );

      // Return items one by one – paid must never exceed total
      for (var i = 0; i < 4; i++) {
        final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
        if (detail!.items.first.returnableQty == 0) break;
        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: detail.items.first,
            quantity: 1,
            reason: 'invariant-rp046',
          ),
        );
        final sale = await ctx.readSale(saleId);
        final paid = (sale['paid_amount'] as num).toDouble();
        final total = (sale['total'] as num).toDouble();
        expect(paid, lessThanOrEqualTo(total + 0.001),
            reason: 'paid_amount must never exceed total');
        _assertSaleInvariant(sale);
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-047 — pending (total - paid_amount) is never negative
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-047 pending balance is never negative after any operation',
        () async {
      final ctx = await _Ctx.fresh('rp047');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp047', qty: 10, cost: 3000.0, price: 5000.0);

      // Over-sell partial pay
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp047',
        qty: 3,
        price: 5000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Collect partial
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 7000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // Return 2 units
      for (var i = 0; i < 2; i++) {
        final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: detail!.items.first,
            quantity: 1,
            reason: 'rp047-$i',
          ),
        );
        final sale = await ctx.readSale(saleId);
        final total = (sale['total'] as num).toDouble();
        final paid = (sale['paid_amount'] as num).toDouble();
        expect(total - paid, greaterThanOrEqualTo(-0.001),
            reason: 'pending must not be negative');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-048 — return cost_price snapshot is stable (historical profit unchanged
    //          by future price changes)
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-048 return cost snapshot in sale_returns is immutable', () async {
      final ctx = await _Ctx.fresh('rp048');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp048', qty: 5, cost: 3000.0, price: 5000.0);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp048',
        qty: 2,
        price: 5000.0,
        paid: 10000.0,
      );

      // Simulate "price change" by directly updating product cost
      await ctx.appDatabase.database.rawUpdate(
        'UPDATE ${TableNames.productModels} SET purchase_price = ? WHERE id = ?',
        <Object?>[9999.0, 'prd_rp048'],
      );

      // Process return – must capture original cost snapshot from sale_items
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'snapshot-test',
        ),
      );

      final returnRows = await ctx.saleReturnRows(saleId);
      expect(returnRows, hasLength(1));
      // cost_price in return row = original 3000 (snap at sale time)
      expect((returnRows.first['cost_price'] as num).toDouble(),
          closeTo(3000.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-049 — payment audit rows are immutable (no overwrites)
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-049 payment audit rows cannot be overwritten', () async {
      final ctx = await _Ctx.fresh('rp049');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp049', qty: 5, cost: 3000.0, price: 5000.0);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp049',
        qty: 2,
        price: 5000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Make 3 payments
      for (final amt in [3000.0, 4000.0, 3000.0]) {
        _ok(
          await ctx.ops.collectPayment(
            saleId: saleId,
            amount: amt,
            paymentMethod: PaymentMethod.cash,
          ),
        );
      }

      // Capture snapshot of all payment rows
      final rowsBefore = await ctx.salePaymentRows(saleId);
      expect(rowsBefore, hasLength(3));

      // Simulate a return that changes sale totals
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: detail!.items.first,
          quantity: 1,
          reason: 'rp049-return',
        ),
      );

      // Payment rows must stay identical (count + content)
      final rowsAfter = await ctx.salePaymentRows(saleId);
      expect(rowsAfter, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(rowsAfter[i]['id'], rowsBefore[i]['id']);
        expect(rowsAfter[i]['amount'], rowsBefore[i]['amount']);
        expect(rowsAfter[i]['created_at'], rowsBefore[i]['created_at']);
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-050 — Final accounting consistency: pending = total - paid always true
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-050 pending = total - paid is mathematically exact after every op',
        () async {
      final ctx = await _Ctx.fresh('rp050');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp050', qty: 20, cost: 2000.0, price: 3000.0);

      // Create two credit sales
      final sale1 = await ctx.sellAccessory(
        productId: 'prd_rp050',
        qty: 5,
        price: 3000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );
      final sale2 = await ctx.sellAccessory(
        productId: 'prd_rp050',
        qty: 4,
        price: 3000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Collect, return, verify invariant after every step
      final operations = <Future<void>>[
        Future<void>(() async {
          _ok(
            await ctx.ops.collectPayment(
              saleId: sale1,
              amount: 5000,
              paymentMethod: PaymentMethod.cash,
            ),
          );
          await _checkPendingInvariant(ctx, sale1);
        }),
        Future<void>(() async {
          final d = _ok(await ctx.ops.getSalesInvoiceDetail(sale2));
          _ok(
            await ctx.ops.processReturn(
              saleId: sale2,
              item: d!.items.first,
              quantity: 2,
              reason: 'rp050-return',
            ),
          );
          await _checkPendingInvariant(ctx, sale2);
        }),
        Future<void>(() async {
          _ok(
            await ctx.ops.collectPayment(
              saleId: sale2,
              amount: 3000,
              paymentMethod: PaymentMethod.cash,
            ),
          );
          await _checkPendingInvariant(ctx, sale2);
        }),
        Future<void>(() async {
          _ok(
            await ctx.ops.collectPayment(
              saleId: sale1,
              amount: 10000,
              paymentMethod: PaymentMethod.cash,
            ),
          );
          await _checkPendingInvariant(ctx, sale1);
        }),
      ];

      // Run sequentially to avoid concurrency issues
      for (final op in operations) {
        await op;
      }

      // Final state invariant check for both sales
      await _checkPendingInvariant(ctx, sale1);
      await _checkPendingInvariant(ctx, sale2);
    });
  });
}

/// Asserts that pending = total - paid (never negative, paid ≤ total).
void _assertSaleInvariant(Map<String, Object?> sale) {
  final total = (sale['total'] as num).toDouble();
  final paid = (sale['paid_amount'] as num).toDouble();
  expect(paid, lessThanOrEqualTo(total + 0.001),
      reason: 'paid_amount must not exceed total');
  expect(total - paid, greaterThanOrEqualTo(-0.001),
      reason: 'pending must not be negative');
}

Future<void> _checkPendingInvariant(_Ctx ctx, String saleId) async {
  final sale = await ctx.readSale(saleId);
  _assertSaleInvariant(sale);
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

  Future<String> sellAccessory({
    required String productId,
    required int qty,
    required double price,
    required double paid,
    String paymentMethod = PaymentMethod.cash,
    String? customerId,
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
