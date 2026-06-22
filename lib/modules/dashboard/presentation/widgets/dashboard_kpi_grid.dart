import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_card_widget.dart';

class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({
    super.key,
    required this.kpis,
  });

  final DashboardKpisEntity kpis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final semantic = theme.semantic;
    final cards = <Widget>[
      DashboardKpiCardWidget(
        label: 'Today Sales',
        value: FormattingHelpers.currencyPkr(kpis.todaySales),
        icon: Icons.payments_outlined,
        color: accent,
      ),
      DashboardKpiCardWidget(
        label: 'Today Profit',
        value: FormattingHelpers.currencyPkr(kpis.todayProfit),
        icon: Icons.trending_up,
        color: kpis.todayProfit >= 0 ? semantic.success : semantic.danger,
      ),
      DashboardKpiCardWidget(
        label: 'Phones Sold Today',
        value: kpis.phonesSoldToday.toString(),
        icon: Icons.phone_android,
        color: accent,
      ),
      DashboardKpiCardWidget(
        label: 'Accessories Sold Today',
        value: kpis.accessoriesSoldToday.toString(),
        icon: Icons.cable,
        color: accent,
      ),
      DashboardKpiCardWidget(
        label: 'Low Stock Count',
        value: kpis.lowStockCount.toString(),
        icon: Icons.warning_amber,
        color: kpis.lowStockCount > 0 ? semantic.warning : semantic.success,
      ),
      DashboardKpiCardWidget(
        label: 'Available Stock Count',
        value: kpis.availableStockCount.toString(),
        icon: Icons.inventory_2_outlined,
        color: accent,
      ),
      DashboardKpiCardWidget(
        label: 'Total Stock Worth',
        value: FormattingHelpers.currencyPkr(kpis.totalStockWorth),
        icon: Icons.savings_outlined,
        color: accent,
      ),
      DashboardKpiCardWidget(
        label: 'Pending Balances',
        value: FormattingHelpers.currencyPkr(kpis.pendingBalances),
        icon: Icons.account_balance_wallet_outlined,
        color: kpis.pendingBalances > 0 ? semantic.warning : semantic.success,
      ),
    ];

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
          itemCount: cards.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: width >= 1500 ? 2.6 : 2.3,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }
}
