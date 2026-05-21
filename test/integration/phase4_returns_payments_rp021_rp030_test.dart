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
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 4 — SECTION D: ACCESSORY RETURNS  (RP-021 … RP-025)
// PHASE 4 — SECTION E: MIXED RETURNS       (RP-026 … RP-030)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION D — ACCESSORY RETURNS
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section D: Accessory Returns', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-021 — Full accessory return restores stock and reverses revenue + cost
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-021 full accessory return restores qty and reverses financials',
        () async {
      final ctx = await _Ctx.fresh('rp021');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp021', qty: 5, cost: 200.0, price: 300.0);

      // Sell 1 unit (cash, fully paid)
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp021',
        qty: 1,
        price: 300.0,
        paid: 300.0,
      );

      final stockBefore = await ctx.getAccessoryQty('prd_rp021');

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

      // Stock +1
      final stockAfter = await ctx.getAccessoryQty('prd_rp021');
      expect(stockAfter, stockBefore + 1);

      // Sale total reduced to 0, paid clamped
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));

      // Return audit row with correct return_amount
      final returnRows = await ctx.saleReturnRows(saleId);
      expect(returnRows, hasLength(1));
      expect((returnRows.first['return_amount'] as num).toDouble(),
          closeTo(300.0, 0.001));
      expect((returnRows.first['return_qty'] as num).toInt(), 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-022 — Partial accessory return (sold=5, return=2)
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-022 partial accessory return adjusts stock and remaining qty',
        () async {
      final ctx = await _Ctx.fresh('rp022');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp022', qty: 10, cost: 200.0, price: 300.0);

      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp022',
        qty: 5,
        price: 300.0,
        paid: 1500.0,
      );

      final stockBefore = await ctx.getAccessoryQty('prd_rp022');

      // Return 2 of the 5
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 2,
          reason: 'customer change of mind',
        ),
      );

      // Stock +2
      final stockAfter = await ctx.getAccessoryQty('prd_rp022');
      expect(stockAfter, stockBefore + 2);

      // returnedQty for item should now be 2
      final detail2 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item2 = detail2!.items.first;
      expect(item2.returnedQty, 2);
      expect(item2.returnableQty, 3);

      // Sale total reduced by 2 * 300 = 600
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(1500.0 - 600.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-023 — Over-return prevention (sold=5, try return=10)
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-023 over-return is blocked and system unchanged', () async {
      final ctx = await _Ctx.fresh('rp023');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp023', qty: 10, cost: 200.0, price: 300.0);

      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp023',
        qty: 5,
        price: 300.0,
        paid: 1500.0,
      );

      final stockBefore = await ctx.getAccessoryQty('prd_rp023');

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      // Try returning 10 (more than sold=5)
      final result = await ctx.ops.processReturn(
        saleId: saleId,
        item: item,
        quantity: 10,
        reason: 'bogus over-return',
      );
      expect(result.isFailure, isTrue);

      // Stock unchanged
      expect(await ctx.getAccessoryQty('prd_rp023'), stockBefore);

      // Sale total unchanged
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(1500.0, 0.001));

      // No return rows
      expect(await ctx.saleReturnRows(saleId), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-024 — Repeated partial returns (5 sold: return 2, 2, 1)
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-024 repeated partial returns track exact remaining qty', () async {
      final ctx = await _Ctx.fresh('rp024');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp024', qty: 10, cost: 200.0, price: 400.0);

      // Sell 5 units
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp024',
        qty: 5,
        price: 400.0,
        paid: 2000.0,
      );

      // Return 2 then 2 then 1
      for (final returnQty in [2, 2, 1]) {
        final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
        final item = detail!.items.first;
        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: item,
            quantity: returnQty,
            reason: 'incremental-return',
          ),
        );
      }

      // All 5 returned → returnableQty = 0
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      expect(detail!.items.first.returnedQty, 5);
      expect(detail.items.first.returnableQty, 0);

      // Total should be 0 (all 5 items returned: 5 * 400 = 2000 reduction)
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));

      // Three return audit rows
      expect(await ctx.saleReturnRows(saleId), hasLength(3));

      // Attempt one more → blocked
      final detail2 = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item2 = detail2!.items.first;
      final blocked = await ctx.ops.processReturn(
        saleId: saleId,
        item: item2,
        quantity: 1,
        reason: 'should be blocked',
      );
      expect(blocked.isFailure, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-025 — Return rollback safety: failed return leaves system unchanged
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-025 failed return leaves system state unchanged', () async {
      final ctx = await _Ctx.fresh('rp025');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp025', qty: 5, cost: 200.0, price: 300.0);
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp025',
        qty: 3,
        price: 300.0,
        paid: 900.0,
      );

      final saleBefore = await ctx.readSale(saleId);
      final stockBefore = await ctx.getAccessoryQty('prd_rp025');
      final returnsBefore = await ctx.saleReturnRows(saleId);

      // Use invalid item (quantity > sold amount)
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;

      final r = await ctx.ops.processReturn(
        saleId: saleId,
        item: item,
        quantity: 99, // way over
        reason: 'force-failure',
      );
      expect(r.isFailure, isTrue);

      // Everything unchanged
      final saleAfter = await ctx.readSale(saleId);
      expect((saleAfter['total'] as num).toDouble(),
          (saleBefore['total'] as num).toDouble());
      expect((saleAfter['paid_amount'] as num).toDouble(),
          (saleBefore['paid_amount'] as num).toDouble());
      expect(await ctx.getAccessoryQty('prd_rp025'), stockBefore);
      expect(await ctx.saleReturnRows(saleId), hasLength(returnsBefore.length));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SECTION E — MIXED RETURNS
  // ─────────────────────────────────────────────────────────────────────────────
  group('PHASE 4 Section E: Mixed Returns', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RP-026 — Mixed invoice: return one item only; other item unaffected
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-026 returning accessory on mixed invoice leaves phone untouched',
        () async {
      final ctx = await _Ctx.fresh('rp026');
      addTearDown(ctx.dispose);

      const imei = '356002600260260';
      await ctx.setupPhone(
          id: 'prd_rp026_phone', imei: imei, cost: 40000, price: 50000);
      await ctx.setupAccessory(
          id: 'prd_rp026_acc', qty: 5, cost: 500.0, price: 800.0);

      final serializedId = await ctx.getSerializedStockId(imei);

      // Mixed invoice: phone + accessory
      final completion = _ok(
        await ctx.sales.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_rp026_phone',
              productName: 'Phone rp026',
              hasImei: true,
              quantity: 1,
              unitPrice: 50000,
              serializedStockId: serializedId,
              imei: imei,
            ),
            const CartItemEntity(
              productModelId: 'prd_rp026_acc',
              productName: 'Acc rp026',
              hasImei: false,
              quantity: 2,
              unitPrice: 800.0,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 51600,
            discount: 0,
            tax: 0,
            total: 51600,
            paidAmount: 51600,
          ),
          saleDate: DateTimeHelpers.nowUtc(),
        ),
      );
      final saleId = completion.saleId;

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final accItem = detail!.items.firstWhere((i) => !i.hasImei);

      // Return only the accessory (2 units)
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: accItem,
          quantity: 2,
          reason: 'wrong accessory',
        ),
      );

      // Phone IMEI stays sold
      expect(await ctx.getImeiStatus(serializedId), 'sold');

      // Sale total reduced by 2 * 800 = 1600
      final sale = await ctx.readSale(saleId);
      expect(
          (sale['total'] as num).toDouble(), closeTo(51600.0 - 1600.0, 0.001));

      // Only one return row
      expect(await ctx.saleReturnRows(saleId), hasLength(1));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-027 — Full mixed invoice return → totals become 0, stock restored
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-027 full mixed return zeroes totals and restores all stock',
        () async {
      final ctx = await _Ctx.fresh('rp027');
      addTearDown(ctx.dispose);

      const imei = '356002700270270';
      await ctx.setupPhone(
          id: 'prd_rp027_phone', imei: imei, cost: 40000, price: 50000);
      await ctx.setupAccessory(
          id: 'prd_rp027_acc', qty: 5, cost: 500.0, price: 1000.0);
      final serializedId = await ctx.getSerializedStockId(imei);

      final completion = _ok(
        await ctx.sales.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_rp027_phone',
              productName: 'Phone rp027',
              hasImei: true,
              quantity: 1,
              unitPrice: 50000,
              serializedStockId: serializedId,
              imei: imei,
            ),
            const CartItemEntity(
              productModelId: 'prd_rp027_acc',
              productName: 'Acc rp027',
              hasImei: false,
              quantity: 1,
              unitPrice: 1000.0,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 51000,
            discount: 0,
            tax: 0,
            total: 51000,
            paidAmount: 51000,
          ),
          saleDate: DateTimeHelpers.nowUtc(),
        ),
      );
      final saleId = completion.saleId;

      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      for (final item in detail!.items) {
        _ok(
          await ctx.ops.processReturn(
            saleId: saleId,
            item: item,
            quantity: item.returnableQty,
            reason: 'full return',
          ),
        );
      }

      // Totals become 0
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(0.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(0.0, 0.001));

      // Phone IMEI restored
      expect(await ctx.getImeiStatus(serializedId), 'in_stock');

      // Return rows for both items
      expect(await ctx.saleReturnRows(saleId), hasLength(2));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-028 — Partial mixed return: math remains correct
    // ─────────────────────────────────────────────────────────────────────────
    test(
        'RP-028 partial return on mixed invoice leaves correct remaining total',
        () async {
      final ctx = await _Ctx.fresh('rp028');
      addTearDown(ctx.dispose);

      const imei = '356002800280280';
      await ctx.setupPhone(
          id: 'prd_rp028_phone', imei: imei, cost: 40000, price: 50000);
      await ctx.setupAccessory(
          id: 'prd_rp028_acc', qty: 5, cost: 500.0, price: 1000.0);
      final serializedId = await ctx.getSerializedStockId(imei);

      final completion = _ok(
        await ctx.sales.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: 'prd_rp028_phone',
              productName: 'Phone rp028',
              hasImei: true,
              quantity: 1,
              unitPrice: 50000,
              serializedStockId: serializedId,
              imei: imei,
            ),
            const CartItemEntity(
              productModelId: 'prd_rp028_acc',
              productName: 'Acc rp028',
              hasImei: false,
              quantity: 3,
              unitPrice: 1000.0,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 53000,
            discount: 0,
            tax: 0,
            total: 53000,
            paidAmount: 53000,
          ),
          saleDate: DateTimeHelpers.nowUtc(),
        ),
      );
      final saleId = completion.saleId;

      // Return 1 accessory only
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final accItem = detail!.items.firstWhere((i) => !i.hasImei);
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: accItem,
          quantity: 1,
          reason: 'partial return',
        ),
      );

      // Sale total = 53000 - 1000 = 52000
      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(52000.0, 0.001));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-029 — Return after payment collection: receivable recalculated safely
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-029 return after partial payment recalculates pending correctly',
        () async {
      final ctx = await _Ctx.fresh('rp029');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp029', qty: 5, cost: 8000.0, price: 10000.0);

      // Credit sale total=20000 (2 units), paid=0
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp029',
        qty: 2,
        price: 10000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Collect 8000
      _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 8000,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      // Return 1 unit (10000)
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'changed mind',
        ),
      );

      // total= 20000-10000=10000, paid=8000 (clamped to min(8000,10000)=8000)
      final sale = await ctx.readSale(saleId);
      final total = (sale['total'] as num).toDouble();
      final paid = (sale['paid_amount'] as num).toDouble();
      expect(total, closeTo(10000.0, 0.001));
      expect(paid, closeTo(8000.0, 0.001));
      // pending = 2000
      expect(total - paid, closeTo(2000.0, 0.001));
      // No negative pending
      expect((total - paid).clamp(0, double.infinity), greaterThanOrEqualTo(0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RP-030 — Payment after return is limited to adjusted balance
    // ─────────────────────────────────────────────────────────────────────────
    test('RP-030 payment after return limited to adjusted pending balance',
        () async {
      final ctx = await _Ctx.fresh('rp030');
      addTearDown(ctx.dispose);

      await ctx.setupAccessory(
          id: 'prd_rp030', qty: 5, cost: 3000.0, price: 5000.0);

      // Credit sale total=10000 (2 units), paid=0
      final saleId = await ctx.sellAccessory(
        productId: 'prd_rp030',
        qty: 2,
        price: 5000.0,
        paid: 0.0,
        paymentMethod: PaymentMethod.credit,
      );

      // Return 1 unit (5000)
      final detail = _ok(await ctx.ops.getSalesInvoiceDetail(saleId));
      final item = detail!.items.first;
      _ok(
        await ctx.ops.processReturn(
          saleId: saleId,
          item: item,
          quantity: 1,
          reason: 'return before payment',
        ),
      );

      // Now total=5000, paid=0, pending=5000
      // Try to pay original full 10000 → blocked (exceeds remaining 5000)
      final overPay = await ctx.ops.collectPayment(
        saleId: saleId,
        amount: 10000,
        paymentMethod: PaymentMethod.cash,
      );
      expect(overPay.isFailure, isTrue);

      // Pay exactly 5000 → succeeds
      final exactPay = _ok(
        await ctx.ops.collectPayment(
          saleId: saleId,
          amount: 5000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      expect(exactPay.remainingBalance, closeTo(0.0, 0.001));

      final sale = await ctx.readSale(saleId);
      expect((sale['total'] as num).toDouble(), closeTo(5000.0, 0.001));
      expect((sale['paid_amount'] as num).toDouble(), closeTo(5000.0, 0.001));
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
        sales = SqliteSalesRepository(appDatabase: appDatabase);

  final Directory _dir;
  final AppDatabase appDatabase;
  final OperationsWorkflowService ops;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository sales;

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
      await sales.createSaleTransaction(
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

  Future<int> getAccessoryQty(String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.single['quantity'] as num).toInt();
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
