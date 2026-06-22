import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_section.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_grid.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardServiceProvider);
    ref.invalidate(dashboardKpisProvider);
    ref.invalidate(dashboardBrandStockProvider);
    ref.invalidate(dashboardPendingReturnsProvider);
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
    final brandStockAsync = ref.watch(dashboardBrandStockProvider);
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
              return ListView(
                padding: const EdgeInsets.all(10),
                children: <Widget>[
                  DashboardHeader(onRefresh: () => _refresh(ref)),
                  const SizedBox(height: 8),
                  kpisAsync.when(
                    data: (kpis) => DashboardKpiGrid(kpis: kpis),
                    loading: () => const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 160,
                      child: Center(
                          child: Text('Failed to load dashboard metrics.')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  brandStockAsync.when(
                    data: (brands) => BrandStockSection(
                      brands: brands,
                      onBrandTap: () {}, // Placeholder for future use
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
                  const SizedBox(height: 12),
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
