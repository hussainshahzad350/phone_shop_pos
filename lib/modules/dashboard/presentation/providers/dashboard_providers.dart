import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_return_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/model_imei_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dealer_stock_breakdown_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_balance_customer_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/daily_sales_point_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_range.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_transaction_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/range_sales_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/sidebar_insights_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/services/dashboard_service.dart';

final dashboardServiceProvider = FutureProvider<DashboardService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return DashboardService(appDatabase: appDatabase);
});

/// Refreshes every dashboard and sidebar data provider after a data-changing
/// event (sale, purchase, return, repair, stock or product edit).
///
/// All dashboard data providers watch [dashboardServiceProvider], so
/// invalidating it cascades a recompute through every one of them — and
/// recreating the service drops its short-lived KPI cache, guaranteeing the
/// next read hits the database. Call this from any screen that just
/// committed a mutation so KPIs, panels and sidebar badges stay live.
void refreshDashboardData(WidgetRef ref) {
  ref.invalidate(dashboardServiceProvider);
}

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
    FutureProvider<List<DashboardLowStockEntity>>((ref) async {
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
  return service.getBrandStock();
});

final dashboardPendingReturnsProvider =
    FutureProvider<List<PendingReturnEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  return service.getPendingReturns();
});

final dashboardTodaySalesDetailsProvider =
    FutureProvider<List<DashboardRecentSaleEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getTodaySalesDetails();
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => const <DashboardRecentSaleEntity>[],
  );
});

final dashboardPendingBalanceDetailsProvider =
    FutureProvider<List<PendingBalanceCustomerEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getPendingBalanceDetails();
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => const <PendingBalanceCustomerEntity>[],
  );
});

final dashboardAllLowStockProvider =
    FutureProvider<List<DashboardLowStockEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getLowStockWarnings(limit: 50);
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => const <DashboardLowStockEntity>[],
  );
});

/// Selected time range for the Key Metrics section (Today / Week / Month).
///
/// autoDispose so the selection resets to Today whenever the user leaves the
/// dashboard — Week/Month are one-off looks, not a sticky preference.
final dashboardRangeProvider =
    StateProvider.autoDispose<DashboardRange>((ref) => DashboardRange.today);

/// Brand Stock section view. Defaults to cards; unlike the metrics range it
/// is a sticky choice — it keeps whatever the user last picked for the whole
/// session, across screen changes.
enum BrandStockView { table, cards }

final brandStockViewProvider =
    StateProvider<BrandStockView>((ref) => BrandStockView.cards);

/// Range-dependent KPIs (sales, profit, units) keyed by range so switching
/// the toggle back and forth reuses cached results within the session.
final dashboardRangeKpisProvider =
    FutureProvider.family<RangeSalesKpisEntity, DashboardRange>(
        (ref, range) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getRangeSalesKpis(range);
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => RangeSalesKpisEntity.empty,
  );
});

/// Net sales per day for the trailing week, for the dashboard bar chart.
final dashboardDailySalesProvider =
    FutureProvider<List<DailySalesPointEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getDailySalesTotals();
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => const <DailySalesPointEntity>[],
  );
});

/// Mixed recent-activity feed (sales, purchases, repairs, payments).
final dashboardRecentTransactionsProvider =
    FutureProvider<List<DashboardTransactionEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getRecentTransactions();
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => const <DashboardTransactionEntity>[],
  );
});

/// Brand stock enriched with per-brand worth and low-stock counts, for the
/// Brand Stock table view.
final dashboardBrandStockDetailsProvider =
    FutureProvider<List<BrandStockEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  return service.getBrandStockDetails();
});

/// Month-to-date top performers + today's activity counts for the sidebar.
final sidebarInsightsProvider =
    FutureProvider<SidebarInsightsEntity>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  final result = await service.getSidebarInsights();
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (_) => SidebarInsightsEntity.empty,
  );
});

final dashboardModelImeiStockProvider =
    FutureProvider.family<List<ModelImeiStockEntity>, String>(
        (ref, brandName) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  return service.getModelImeiStock(brandName);
});

final dashboardDealerStockBreakdownProvider =
    FutureProvider<List<DealerStockBreakdownEntity>>((ref) async {
  final service = await ref.watch(dashboardServiceProvider.future);
  return service.getDealerStockBreakdown();
});
