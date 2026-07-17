import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/widgets/app_skeleton.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/alerts_section.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_popup.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_section.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_low_stock_card.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_sales_chart_card.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_transactions_card.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardServiceProvider);
    ref.invalidate(dashboardKpisProvider);
    ref.invalidate(dashboardRangeKpisProvider);
    ref.invalidate(dashboardDailySalesProvider);
    ref.invalidate(dashboardRecentTransactionsProvider);
    ref.invalidate(dashboardLowStockProvider);
    ref.invalidate(dashboardBrandStockDetailsProvider);
    ref.invalidate(dashboardPendingReturnsProvider);
    ref.invalidate(sidebarInsightsProvider);
  }

  Future<void> _showBrandStockPopup(
    BuildContext context,
    BrandStockEntity brand,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => BrandStockPopup(brand: brand),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final range = ref.watch(dashboardRangeProvider);
    final rangeKpisAsync = ref.watch(dashboardRangeKpisProvider(range));
    final dailySalesAsync = ref.watch(dashboardDailySalesProvider);
    final transactionsAsync = ref.watch(dashboardRecentTransactionsProvider);
    final lowStockAsync = ref.watch(dashboardLowStockProvider);
    final brandStockAsync = ref.watch(dashboardBrandStockDetailsProvider);
    final pendingReturnsAsync = ref.watch(dashboardPendingReturnsProvider);

    final alertsSection = pendingReturnsAsync.when(
      data: (returns) => AlertsSection(
        lowStockCount: 0,
        pendingReturns: returns,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f5): _RefreshDashboardIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RefreshDashboardIntent: CallbackAction<_RefreshDashboardIntent>(
            onInvoke: (_) {
              _refresh(ref);
              return null;
            },
          ),
        },
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: <Widget>[
                  DashboardHeader(onRefresh: () => _refresh(ref)),
                  const SizedBox(height: AppSpacing.sm),
                  kpisAsync.when(
                    data: (kpis) => DashboardKpiGrid(
                      kpis: kpis,
                      range: range,
                      rangeKpis: rangeKpisAsync.valueOrNull,
                    ),
                    loading: () => const _DashboardKpiSkeleton(),
                    error: (_, __) => const SizedBox(
                      height: 160,
                      child: Center(
                          child: Text('Failed to load dashboard metrics.')),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActivitySection(
                    isWide: isWide,
                    chart: dailySalesAsync.when(
                      data: (points) =>
                          DashboardSalesChartCard(points: points),
                      loading: () => const AppSkeletonCard(),
                      error: (_, __) => const Card(
                        child:
                            Center(child: Text('Failed to load sales chart.')),
                      ),
                    ),
                    transactions: transactionsAsync.when(
                      data: (rows) =>
                          DashboardTransactionsCard(transactions: rows),
                      loading: () => const AppSkeletonCard(),
                      error: (_, __) => const Card(
                        child: Center(
                            child: Text('Failed to load transactions.')),
                      ),
                    ),
                    lowStock: lowStockAsync.when(
                      data: (rows) => DashboardLowStockCard(rows: rows),
                      loading: () => const AppSkeletonCard(),
                      error: (_, __) => const Card(
                        child:
                            Center(child: Text('Failed to load low stock.')),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  brandStockAsync.when(
                    data: (brands) => BrandStockSection(
                      brands: brands,
                      onBrandTap: (brand) =>
                          _showBrandStockPopup(context, brand),
                    ),
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 200,
                      child: Center(child: Text('Failed to load brand stock.')),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  alertsSection,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RefreshDashboardIntent extends Intent {
  const _RefreshDashboardIntent();
}

/// Middle band of the v2 dashboard: sales chart, recent transactions and low
/// stock. Side by side (1.3 : 1 : 1) on wide desktop, stacked otherwise.
class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.isWide,
    required this.chart,
    required this.transactions,
    required this.lowStock,
  });

  final bool isWide;
  final Widget chart;
  final Widget transactions;
  final Widget lowStock;

  static const double _panelHeight = 280;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return SizedBox(
        height: _panelHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: 13, child: chart),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 10, child: transactions),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 10, child: lowStock),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(height: _panelHeight, child: chart),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: _panelHeight, child: transactions),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: _panelHeight, child: lowStock),
      ],
    );
  }
}

/// Skeleton placeholder for the KPI grid, mirroring its responsive column
/// count so the layout doesn't jump when real cards arrive.
class _DashboardKpiSkeleton extends StatelessWidget {
  const _DashboardKpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1500
            ? 5
            : width >= 1100
                ? 4
                : width >= 760
                    ? 3
                    : 2;
        return GridView.builder(
          shrinkWrap: true,
          itemCount: 8,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: width >= 1500 ? 2.6 : 2.3,
          ),
          itemBuilder: (_, __) => const AppSkeletonCard(),
        );
      },
    );
  }
}
