import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/customers/data/repositories/sqlite_customer_repository.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/operations_history_query_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/stock_adjustment_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

/// Behavioural coverage for the previously untested OperationsHistoryQueryService
/// read models: sales-history search filters, purchase-history search, and the
/// stock-adjustment history feed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;

  setUp(() async {
    ctx = await _Ctx.fresh();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  group('searchSalesHistory', () {
    Future<void> seedTwoSales() async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 200, price: 1000);
      await ctx.createCustomer('cust-ali', 'Ali');
      // Credit sale to a registered customer (pending balance).
      await ctx.sell(
        productId: 'acc-1',
        price: 1000,
        paid: 0,
        method: PaymentMethod.credit,
        customerId: 'cust-ali',
      );
      // Cash walk-in sale, fully paid.
      await ctx.sell(
        productId: 'acc-1',
        price: 500,
        paid: 500,
        method: PaymentMethod.cash,
      );
    }

    Future<List<SalesHistoryRowEntity>> search({
      String invoice = '',
      String customer = '',
      bool pendingOnly = false,
      bool collectibleOnly = false,
    }) async =>
        _ok(await ctx.history.searchSalesHistory(
          invoiceQuery: invoice,
          customerQuery: customer,
          startDate: null,
          endDate: null,
          pendingOnly: pendingOnly,
          collectibleOnly: collectibleOnly,
        ));

    test('returns all sales when unfiltered', () async {
      await seedTwoSales();
      expect(await search(), hasLength(2));
    });

    test('filters by customer name', () async {
      await seedTwoSales();
      final rows = await search(customer: 'Ali');
      expect(rows, hasLength(1));
      expect(rows.single.customerName, 'Ali');
    });

    test('pendingOnly returns only sales with an outstanding balance', () async {
      await seedTwoSales();
      final rows = await search(pendingOnly: true);
      expect(rows, hasLength(1));
      expect(rows.single.total - rows.single.paidAmount, closeTo(1000, 0.01));
    });

    test('collectibleOnly returns only credit sales to registered customers',
        () async {
      await seedTwoSales();
      final rows = await search(collectibleOnly: true);
      expect(rows, hasLength(1));
      expect(rows.single.customerName, 'Ali');
    });
  });

  group('getStockAdjustments', () {
    test('surfaces an applied quantity adjustment with its product and delta',
        () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 200, price: 1000);
      _ok(await ctx.adjustments.applyQuantityStockAdjustment(
        productModelId: 'acc-1',
        delta: -2,
        reason: 'correction',
      ));

      final rows = _ok(await ctx.history.getStockAdjustments());
      expect(rows, hasLength(1));
      expect(rows.single.productName, 'Product acc-1');
      expect(rows.single.adjustmentType, 'decrease');
      expect(rows.single.quantityDelta, -2);
      expect(rows.single.reason, 'correction');
    });
  });

  group('searchPurchaseHistory', () {
    test('returns seeded purchases when unfiltered', () async {
      await ctx.setupAccessory(id: 'acc-1', qty: 5, cost: 200, price: 1000);

      final rows = _ok(await ctx.history.searchPurchaseHistory(
        supplierQuery: '',
        startDate: null,
        endDate: null,
      ));
      expect(rows, isNotEmpty);
      // Purchase total = qty * cost = 5 * 200 = 1000.
      expect(rows.first.total, closeTo(1000, 0.01));
    });
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        _products = SqliteProductRepository(appDatabase: db),
        _purchases = SqlitePurchaseRepository(appDatabase: db),
        _sales = SqliteSalesRepository(appDatabase: db),
        _customers = SqliteCustomerRepository(appDatabase: db),
        adjustments = StockAdjustmentService(appDatabase: db),
        history = OperationsHistoryQueryService(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository _products;
  final SqlitePurchaseRepository _purchases;
  final SqliteSalesRepository _sales;
  final SqliteCustomerRepository _customers;
  final StockAdjustmentService adjustments;
  final OperationsHistoryQueryService history;

  static Future<_Ctx> fresh() async {
    final dir =
        await Directory.systemTemp.createTemp('phone_shop_pos_ops_history_');
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

  Future<void> sell({
    required String productId,
    required double price,
    required double paid,
    required String method,
    String? customerId,
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
          paidAmount: paid,
        ),
        customerId: customerId,
        paymentMethod: method,
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
