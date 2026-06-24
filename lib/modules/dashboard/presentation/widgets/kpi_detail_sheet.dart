import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_balance_customer_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dealer_stock_breakdown_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

void showKpiDetailSheet(
  BuildContext context,
  String cardId,
  String label,
  String displayValue,
  Color color,
  DashboardKpisEntity kpis,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _KpiDetailSheet(
      cardId: cardId,
      label: label,
      displayValue: displayValue,
      color: color,
      kpis: kpis,
    ),
  );
}

class _KpiDetailSheet extends ConsumerWidget {
  const _KpiDetailSheet({
    required this.cardId,
    required this.label,
    required this.displayValue,
    required this.color,
    required this.kpis,
  });

  final String cardId;
  final String label;
  final String displayValue;
  final Color color;
  final DashboardKpisEntity kpis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  radius: 20,
                  child: Icon(_iconForCard(cardId), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        displayValue,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Flexible(child: _buildContent(context, ref, theme)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ThemeData theme) {
    switch (cardId) {
      case 'today_sales':
        return const _TodaySalesContent();
      case 'today_profit':
        return _TodayProfitContent(kpis: kpis);
      case 'phones_sold_today':
        return _SimpleInfoContent(
          icon: Icons.phone_android,
          primary: '${kpis.phonesSoldToday} phone(s) sold today',
          hint: 'Open the Sales module to see the full phone sales list.',
        );
      case 'accessories_sold_today':
        return _SimpleInfoContent(
          icon: Icons.cable,
          primary: '${kpis.accessoriesSoldToday} accessory item(s) sold today',
          hint: 'Open the Sales module to see the full accessories sales list.',
        );
      case 'low_stock_count':
        return const _LowStockContent();
      case 'available_stock_count':
        return _SimpleInfoContent(
          icon: Icons.inventory_2_outlined,
          primary: '${kpis.availableStockCount} total units in stock',
          hint:
              'This includes all in-stock phones and accessories. Check the Inventory module for a full breakdown.',
        );
      case 'total_stock_worth':
        return _SimpleInfoContent(
          icon: Icons.savings_outlined,
          primary:
              'Stock worth: ${FormattingHelpers.currencyPkr(kpis.totalStockWorth)}',
          hint:
              'Calculated using cost price of all in-stock phones and accessories.',
        );
      case 'pending_balances':
        return const _PendingBalancesContent();
      case 'dealer_stock':
        return const _DealerStockContent();
      default:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No detail available.'),
          ),
        );
    }
  }

  IconData _iconForCard(String id) {
    switch (id) {
      case 'today_sales':
        return Icons.payments_outlined;
      case 'today_profit':
        return Icons.trending_up;
      case 'phones_sold_today':
        return Icons.phone_android;
      case 'accessories_sold_today':
        return Icons.cable;
      case 'low_stock_count':
        return Icons.warning_amber;
      case 'available_stock_count':
        return Icons.inventory_2_outlined;
      case 'total_stock_worth':
        return Icons.savings_outlined;
      case 'pending_balances':
        return Icons.account_balance_wallet_outlined;
      case 'dealer_stock':
        return Icons.swap_horiz_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

// ── Today Sales ──────────────────────────────────────────────────────────────

class _TodaySalesContent extends ConsumerWidget {
  const _TodaySalesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardTodaySalesDetailsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load sales.')),
      data: (sales) {
        if (sales.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sales recorded today.'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, i) => _SaleTile(sale: sales[i]),
        );
      },
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});
  final DashboardRecentSaleEntity sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPending = sale.pendingAmount > 0;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.receipt_outlined,
            size: 16, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(sale.customerName, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        '${sale.invoiceNumber} · ${FormattingHelpers.dateYmdHm(sale.saleDate)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            FormattingHelpers.currencyPkr(sale.total),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (hasPending)
            Text(
              'Due: ${FormattingHelpers.currencyPkr(sale.pendingAmount)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Today Profit ─────────────────────────────────────────────────────────────

class _TodayProfitContent extends StatelessWidget {
  const _TodayProfitContent({required this.kpis});
  final DashboardKpisEntity kpis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = kpis.todayProfit >= 0;
    final profitColor = isPositive
        ? theme.semantic.success
        : theme.semantic.danger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ProfitRow(
            label: 'Total Profit Today',
            value: FormattingHelpers.currencyPkr(kpis.todayProfit),
            valueColor: profitColor,
            isBold: true,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _ProfitRow(
            label: 'Phones Sold',
            value: '${kpis.phonesSoldToday} units',
          ),
          const SizedBox(height: 8),
          _ProfitRow(
            label: 'Accessories Sold',
            value: '${kpis.accessoriesSoldToday} items',
          ),
          const SizedBox(height: 8),
          _ProfitRow(
            label: 'Today Revenue',
            value: FormattingHelpers.currencyPkr(kpis.todaySales),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadii.smRadius,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profit is calculated as revenue minus cost price, adjusted for any returns processed today.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitRow extends StatelessWidget {
  const _ProfitRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isBold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          )
        : theme.textTheme.bodyMedium?.copyWith(color: valueColor);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: isBold
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium,
        ),
        Text(value, style: style),
      ],
    );
  }
}

// ── Low Stock ─────────────────────────────────────────────────────────────────

class _LowStockContent extends ConsumerWidget {
  const _LowStockContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardAllLowStockProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load stock data.')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_outline,
                      color: Theme.of(context).semantic.success),
                  const SizedBox(width: 8),
                  const Text('All accessories are sufficiently stocked.'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, i) => _LowStockTile(item: items[i]),
        );
      },
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.item});
  final DashboardLowStockEntity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = item.quantity == 0;
    final color =
        isCritical ? theme.semantic.danger : theme.semantic.warning;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isCritical ? Icons.error_outline : Icons.warning_amber,
          size: 16,
          color: color,
        ),
      ),
      title: Text(item.productName, style: theme.textTheme.bodyMedium),
      subtitle: item.location != null
          ? Text(item.location!, style: theme.textTheme.bodySmall)
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '${item.quantity} in stock',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Min: ${item.minQuantity}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Pending Balances ──────────────────────────────────────────────────────────

class _PendingBalancesContent extends ConsumerWidget {
  const _PendingBalancesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardPendingBalanceDetailsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load balance data.')),
      data: (customers) {
        if (customers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_outline,
                      color: Theme.of(context).semantic.success),
                  const SizedBox(width: 8),
                  const Text('No pending balances outstanding.'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: customers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, i) =>
              _PendingBalanceTile(customer: customers[i]),
        );
      },
    );
  }
}

class _PendingBalanceTile extends StatelessWidget {
  const _PendingBalanceTile({required this.customer});
  final PendingBalanceCustomerEntity customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.semantic.warning.withValues(alpha: 0.12),
        child: Icon(Icons.person_outline,
            size: 16, color: theme.semantic.warning),
      ),
      title: Text(customer.customerName, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        '${customer.invoiceNumber} · ${FormattingHelpers.dateYmd(customer.saleDate)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        FormattingHelpers.currencyPkr(customer.pendingAmount),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.semantic.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Dealer Stock ──────────────────────────────────────────────────────────────

class _DealerStockContent extends ConsumerWidget {
  const _DealerStockContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardDealerStockBreakdownProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load dealer data.')),
      data: (dealers) {
        if (dealers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_outline,
                      color: Theme.of(context).semantic.success),
                  const SizedBox(width: 8),
                  const Text('No phones currently with dealers.'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: dealers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, i) => _DealerStockTile(item: dealers[i]),
        );
      },
    );
  }
}

class _DealerStockTile extends StatelessWidget {
  const _DealerStockTile({required this.item});
  final DealerStockBreakdownEntity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(Icons.person_outline,
            size: 16, color: theme.colorScheme.onSecondaryContainer),
      ),
      title: Text(item.dealerName, style: theme.textTheme.bodyMedium),
      trailing: Text(
        '${item.count} phone${item.count == 1 ? '' : 's'}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Simple Info ───────────────────────────────────────────────────────────────

class _SimpleInfoContent extends StatelessWidget {
  const _SimpleInfoContent({
    required this.icon,
    required this.primary,
    required this.hint,
  });

  final IconData icon;
  final String primary;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              primary,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

