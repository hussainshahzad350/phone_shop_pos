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
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: <Widget>[
                  DashboardHeader(onRefresh: () => _refresh(ref)),
                  const SizedBox(height: AppSpacing.sm),
                  kpisAsync.when(
                    data: (kpis) => DashboardKpiGrid(kpis: kpis),
                    loading: () => const _DashboardKpiSkeleton(),
                    error: (_, __) => const SizedBox(
                      height: 160,
                      child: Center(
                          child: Text('Failed to load dashboard metrics.')),
                    ),
                  ),
                  const _SectionDivider(),
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

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Brand Stock',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
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
