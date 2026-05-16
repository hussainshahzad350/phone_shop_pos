import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/services/dashboard_service.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

void main() {
  group('Performance hardening validations', () {
    test('dashboard KPI memoization avoids immediate re-query and respects TTL',
        () async {
      final context = await _PerfContext.createTemporary();
      addTearDown(context.dispose);

      var now = DateTime.utc(2026, 5, 16, 10);
      final service = DashboardService(
        appDatabase: context.appDatabase,
        nowProvider: () => now,
      );

      await context.insertProduct(
        id: 'prd_dash_phone',
        name: 'Dashboard Phone',
        hasImei: true,
      );
      await context.insertSaleWithItem(
        saleId: 'sal_dash_1',
        itemId: 'sit_dash_1',
        productModelId: 'prd_dash_phone',
        saleDate: now,
        total: 120000,
        paidAmount: 110000,
        quantity: 1,
        costPrice: 100000,
        lineTotal: 120000,
      );

      final first = await service.getDashboardKpis();
      expect(first.isSuccess, isTrue);
      expect(first.asSuccess!.value.todaySales, 120000);

      await context.appDatabase.database.delete(TableNames.saleItems);
      await context.appDatabase.database.delete(TableNames.sales);

      final second = await service.getDashboardKpis();
      expect(second.isSuccess, isTrue);
      expect(second.asSuccess!.value.todaySales, 120000);

      now = now.add(const Duration(seconds: 25));
      final third = await service.getDashboardKpis();
      expect(third.isSuccess, isTrue);
      expect(third.asSuccess!.value.todaySales, 0);
    });

    test('inventory stock query respects search and limit boundaries', () async {
      final context = await _PerfContext.createTemporary();
      addTearDown(context.dispose);
      final repository = SqliteInventoryRepository(appDatabase: context.appDatabase);

      for (var i = 0; i < 220; i++) {
        final id = 'prd_ser_$i';
        await context.insertProduct(
          id: id,
          name: 'Serialized Model $i',
          hasImei: true,
          sku: 'SER-$i',
        );
        await context.insertSerializedStock(
          id: 'ser_$i',
          productModelId: id,
          imei1: i < 120 ? '999000$i' : '888000$i',
        );
      }

      for (var i = 0; i < 220; i++) {
        final id = 'prd_qty_$i';
        await context.insertProduct(
          id: id,
          name: i < 60 ? '999 Accessory $i' : 'Accessory $i',
          hasImei: false,
          sku: 'ACC-$i',
        );
        await context.insertInventoryStock(
          id: 'stk_$i',
          productModelId: id,
          quantity: 10 + i,
          minQuantity: 2,
        );
      }

      final searched = await repository.getStockRows(searchQuery: '999', limit: 40);
      expect(searched.isSuccess, isTrue);
      final searchedRows = searched.asSuccess!.value;
      expect(searchedRows.length, lessThanOrEqualTo(40));

      final limited = await repository.getStockRows(limit: 50);
      expect(limited.isSuccess, isTrue);
      expect(limited.asSuccess!.value.length, 50);
    });

    test('report filter options are search-aware and capped', () async {
      final context = await _PerfContext.createTemporary();
      addTearDown(context.dispose);

      for (var i = 0; i < 320; i++) {
        final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
        await context.appDatabase.insert(TableNames.customers, <String, Object?>{
          'id': 'cus_$i',
          'name': 'Customer $i',
          'phone': '0300${i.toString().padLeft(7, '0')}',
          'created_at': now,
          'updated_at': now,
          'is_active': 1,
        });
      }

      for (var i = 0; i < 320; i++) {
        await context.insertProduct(
          id: 'prd_opt_$i',
          name: 'Product $i',
          hasImei: false,
          sku: 'SKU-$i',
        );
      }

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWith((ref) async => context.appDatabase),
        ],
      );
      addTearDown(container.dispose);

      final customers = await container.read(reportCustomerOptionsProvider.future);
      expect(customers.length, reportFilterOptionsLimit);

      container.read(reportCustomerOptionSearchProvider.notifier).state = 'Customer 319';
      final searchedCustomers =
          await container.read(reportCustomerOptionsProvider.future);
      expect(searchedCustomers.length, 1);
      expect(searchedCustomers.first.value, 'Customer 319');

      final products = await container.read(reportProductOptionsProvider.future);
      expect(products.length, reportFilterOptionsLimit);

      container.read(reportProductOptionSearchProvider.notifier).state = 'Product 319';
      final searchedProducts = await container.read(reportProductOptionsProvider.future);
      expect(searchedProducts.length, 1);
      expect(searchedProducts.first.value, 'Product 319');
    });
  });
}

class _PerfContext {
  _PerfContext({
    required this.rootDirectory,
    required this.appDatabase,
  });

  final Directory rootDirectory;
  final AppDatabase appDatabase;

  static Future<_PerfContext> createTemporary() async {
    final root = await Directory.systemTemp.createTemp('phone_shop_pos_perf_');
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _PerfContext(rootDirectory: root, appDatabase: appDatabase);
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }

  Future<void> insertProduct({
    required String id,
    required String name,
    required bool hasImei,
    String? sku,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
    await appDatabase.insert(TableNames.productModels, <String, Object?>{
      'id': id,
      'name': name,
      'sku': sku,
      'purchase_price': 5000,
      'sale_price': 6500,
      'has_imei': hasImei ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertSerializedStock({
    required String id,
    required String productModelId,
    required String imei1,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
    await appDatabase.insert(TableNames.serializedStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'imei1': imei1,
      'stock_status': 'in_stock',
      'cost_price': 5000,
      'selling_price': 6500,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertInventoryStock({
    required String id,
    required String productModelId,
    required int quantity,
    required int minQuantity,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 16));
    await appDatabase.insert(TableNames.inventoryStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'unit_cost': 100,
      'unit_price': 150,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertSaleWithItem({
    required String saleId,
    required String itemId,
    required String productModelId,
    required DateTime saleDate,
    required double total,
    required double paidAmount,
    required int quantity,
    required double costPrice,
    required double lineTotal,
  }) async {
    final sqlNow = DateTimeHelpers.toSql(saleDate);
    await appDatabase.insert(TableNames.sales, <String, Object?>{
      'id': saleId,
      'invoice_number': 'INV-$saleId',
      'sale_date': sqlNow,
      'subtotal': total,
      'discount': 0,
      'tax': 0,
      'total': total,
      'paid_amount': paidAmount,
      'created_at': sqlNow,
      'updated_at': sqlNow,
    });
    await appDatabase.insert(TableNames.saleItems, <String, Object?>{
      'id': itemId,
      'sale_id': saleId,
      'product_model_id': productModelId,
      'quantity': quantity,
      'unit_price': lineTotal / quantity,
      'discount': 0,
      'line_total': lineTotal,
      'cost_price': costPrice,
      'created_at': sqlNow,
      'updated_at': sqlNow,
    });
  }
}
