import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/ledger_facade_service.dart';

/// Coverage for LedgerFacadeService.getSupplierLedger. Without a ledger-posting
/// service wired in, the facade falls back to aggregating the purchases table
/// per supplier — this pins that fallback aggregation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;

  setUp(() async {
    ctx = await _Ctx.fresh();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test('aggregates purchases per supplier via the fallback query', () async {
    await ctx.buyStock(id: 'acc-1', qty: 5, cost: 100); // total 500
    await ctx.buyStock(id: 'acc-2', qty: 2, cost: 50); // total 100

    final rows = _ok(await ctx.ledger.getSupplierLedger(
      startDate: null,
      endDate: null,
    ));

    // Neither purchase names a supplier, so both group under "Unknown Supplier".
    expect(rows, hasLength(1));
    expect(rows.single.supplierName, 'Unknown Supplier');
    expect(rows.single.purchaseCount, 2);
    expect(rows.single.totalPurchases, closeTo(600, 0.01));
    expect(rows.single.totalPaid, closeTo(600, 0.01));
  });

  test('returns an empty ledger when there are no purchases', () async {
    final rows = _ok(await ctx.ledger.getSupplierLedger(
      startDate: null,
      endDate: null,
    ));
    expect(rows, isEmpty);
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        ledger = LedgerFacadeService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final LedgerFacadeService ledger;

  static Future<_Ctx> fresh() async {
    final dir =
        await Directory.systemTemp.createTemp('phone_shop_pos_ledger_facade_');
    final db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
    return _Ctx(dir: dir, db: db);
  }

  Future<void> dispose() async {
    await db.close();
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
  }

  Future<void> buyStock({
    required String id,
    required int qty,
    required double cost,
  }) async {
    final now = DateTimeHelpers.nowUtc();
    _ok(
      await _products.createProduct(
        ProductEntity(
          id: id,
          name: 'Product $id',
          sku: 'SKU-$id',
          purchasePrice: cost,
          salePrice: cost * 1.5,
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
}

T _ok<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.isFailure ? result.asFailure!.error.message : '',
  );
  return result.asSuccess!.value;
}
