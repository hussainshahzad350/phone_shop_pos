import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/services/dashboard_service.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';

final dashboardServiceProvider = FutureProvider<DashboardService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return DashboardService(appDatabase: appDatabase);
});

final dashboardKpisProvider = FutureProvider<DashboardKpisEntity>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getDashboardKpis();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const DashboardKpisEntity(
      todaySales: 0,
      todayProfit: 0,
      phonesSoldToday: 0,
      accessoriesSoldToday: 0,
      lowStockCount: 0,
      availableStockCount: 0,
      pendingBalances: 0,
      totalStockWorth: 0,
    ),
  );
});

final dashboardRecentSalesProvider =
    FutureProvider<List<DashboardRecentSaleEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getRecentSales(limit: 10);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const <DashboardRecentSaleEntity>[],
  );
});

final dashboardLowStockProvider =
    FutureProvider<List<DashboardLowStockEntity>>((
  ref,
) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getLowStockWarnings(limit: 8);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const <DashboardLowStockEntity>[],
  );
});

final dashboardBrandStockProvider =
    FutureProvider<List<BrandStockEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getBrandStock();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const <BrandStockEntity>[],
  );
});

final brandPhoneModelsProvider = FutureProvider.family<
    List<ProductEntity>, String>((ref, brandName) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  final result = await repository.searchProducts(
    brandName,
    hasImei: true,
    isActive: true,
    limit: 200,
  );
  return result.fold(
    onSuccess: (items) => items
        .where((item) => item.brand?.trim().toLowerCase() ==
            brandName.trim().toLowerCase())
        .toList(growable: false),
    onFailure: (_) => const <ProductEntity>[],
  );
});

final brandPhoneStockRowsProvider = FutureProvider.family<
    List<StockRowEntity>, String>((ref, brandName) async {
  final repository = await ref.watch(inventoryRepositoryProvider.future);
  final result = await repository.getStockRows(
    searchQuery: brandName,
    hasImeiFilter: true,
    serializedStatusFilter: SerializedStockStatus.inStock,
    limit: 1000,
  );
  return result.fold(
    onSuccess: (items) => items
        .where((item) => item.brand?.trim().toLowerCase() ==
            brandName.trim().toLowerCase())
        .toList(growable: false),
    onFailure: (_) => const <StockRowEntity>[],
  );
});
