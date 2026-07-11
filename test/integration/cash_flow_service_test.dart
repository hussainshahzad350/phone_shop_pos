import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/cash_flow_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

/// Behavioural coverage for the previously untested CashFlowService.getCashLedger.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;

  setUp(() async {
    ctx = await _Ctx.fresh();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  double totalCashIn(List<CashLedgerRowEntity> rows) =>
      rows.fold<double>(0, (sum, row) => sum + row.totalCashIn);

  test('a cash sale surfaces as cash-in in the ledger', () async {
    await ctx.setupAccessory(id: 'acc-1', qty: 3, cost: 200, price: 1000);
    await ctx.sellAccessoryCash(productId: 'acc-1', price: 1000);

    final rows = _ok(await ctx.cashFlow.getCashLedger(
      startDate: null,
      endDate: null,
    ));

    expect(rows, isNotEmpty);
    // The 1000 cash taken at the point of sale must be reflected as cash-in
    // (whether classified as a sale-in or an initial collection).
    expect(totalCashIn(rows), greaterThanOrEqualTo(1000 - 0.01));
  });

  test('a date window in the future excludes today\'s cash sale', () async {
    await ctx.setupAccessory(id: 'acc-1', qty: 3, cost: 200, price: 1000);
    await ctx.sellAccessoryCash(productId: 'acc-1', price: 1000);

    final future = DateTime.now().add(const Duration(days: 2));
    final rows = _ok(await ctx.cashFlow.getCashLedger(
      startDate: future,
      endDate: future,
    ));

    expect(totalCashIn(rows), closeTo(0, 0.01));
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        _sales = SqliteSalesRepository(appDatabase: db),
        cashFlow = CashFlowService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository _sales;
  final CashFlowService cashFlow;

  static Future<_Ctx> fresh() async {
    final dir =
        await Directory.systemTemp.createTemp('phone_shop_pos_cash_flow_');
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

  Future<void> sellAccessoryCash({
    required String productId,
    required double price,
  }) async {
    _ok(
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
          subtotal: price,
          discount: 0,
          tax: 0,
          total: price,
          paidAmount: price,
        ),
        customerId: null,
        paymentMethod: PaymentMethod.cash,
        saleDate: DateTimeHelpers.nowUtc(),
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
