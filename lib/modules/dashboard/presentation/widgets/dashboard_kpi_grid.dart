import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/kpi_card_config.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/kpi_preferences_provider.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_card_widget.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/kpi_customize_dialog.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/kpi_detail_sheet.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class DashboardKpiGrid extends ConsumerWidget {
  const DashboardKpiGrid({super.key, required this.kpis});

  final DashboardKpisEntity kpis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(kpiPreferencesProvider);
    final configs = prefsAsync.valueOrNull ?? kpiCardDefaults;
    final visibleConfigs = configs.where((c) => c.visible).toList();

    final accent = theme.colorScheme.primary;
    final semantic = theme.semantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Key Metrics',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showKpiCustomizeDialog(context),
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('Customize'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
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
              itemCount: visibleConfigs.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: width >= 1500 ? 2.6 : 2.3,
              ),
              itemBuilder: (_, index) => _buildCard(
                context,
                visibleConfigs[index],
                accent,
                semantic,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    KpiCardConfig cfg,
    Color accent,
    AppSemanticColors semantic,
  ) {
    late final String label;
    late final String value;
    late final IconData icon;
    late final Color color;

    switch (cfg.id) {
      case 'today_sales':
        label = 'Today Sales';
        value = FormattingHelpers.currencyPkr(kpis.todaySales);
        icon = Icons.payments_outlined;
        color = accent;
        break;
      case 'today_profit':
        label = 'Today Profit';
        value = FormattingHelpers.currencyPkr(kpis.todayProfit);
        icon = Icons.trending_up;
        color = kpis.todayProfit >= 0 ? semantic.success : semantic.danger;
        break;
      case 'phones_sold_today':
        label = 'Phones Sold Today';
        value = kpis.phonesSoldToday.toString();
        icon = Icons.phone_android;
        color = accent;
        break;
      case 'accessories_sold_today':
        label = 'Accessories Sold Today';
        value = kpis.accessoriesSoldToday.toString();
        icon = Icons.cable;
        color = accent;
        break;
      case 'low_stock_count':
        label = 'Low Stock Count';
        value = kpis.lowStockCount.toString();
        icon = Icons.warning_amber;
        color = kpis.lowStockCount > 0 ? semantic.warning : semantic.success;
        break;
      case 'available_stock_count':
        label = 'Available Stock Count';
        value = kpis.availableStockCount.toString();
        icon = Icons.inventory_2_outlined;
        color = accent;
        break;
      case 'total_stock_worth':
        label = 'Total Stock Worth';
        value = FormattingHelpers.currencyPkr(kpis.totalStockWorth);
        icon = Icons.savings_outlined;
        color = accent;
        break;
      case 'pending_balances':
        label = 'Pending Balances';
        value = FormattingHelpers.currencyPkr(kpis.pendingBalances);
        icon = Icons.account_balance_wallet_outlined;
        color = kpis.pendingBalances > 0 ? semantic.warning : semantic.success;
        break;
      case 'dealer_stock':
        label = 'Phones with Dealers';
        value = kpis.dealerStockCount.toString();
        icon = Icons.swap_horiz_outlined;
        color = kpis.dealerStockCount > 0 ? semantic.warning : accent;
        break;
      default:
        return const SizedBox.shrink();
    }

    return DashboardKpiCardWidget(
      label: label,
      value: value,
      icon: icon,
      color: color,
      onTap: () => showKpiDetailSheet(
        context,
        cfg.id,
        label,
        value,
        color,
        kpis,
      ),
    );
  }
}
