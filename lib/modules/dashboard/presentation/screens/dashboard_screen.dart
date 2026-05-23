import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_card_widget.dart';

const double _dashboardNarrowWidthBreakpoint = 1100;
const double _dashboardCompactHeightThreshold = 820;
const double _dashboardCompactPanelHeight = 340;
const double _dashboardDefaultPanelHeight = 420;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardServiceProvider);
    ref.invalidate(dashboardKpisProvider);
    ref.invalidate(dashboardRecentSalesProvider);
    ref.invalidate(dashboardLowStockProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final recentSalesAsync = ref.watch(dashboardRecentSalesProvider);
    final lowStockAsync = ref.watch(dashboardLowStockProvider);

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
              final isNarrow =
                  constraints.maxWidth < _dashboardNarrowWidthBreakpoint;
              final panelHeight =
                  constraints.maxHeight < _dashboardCompactHeightThreshold
                      ? _dashboardCompactPanelHeight
                      : _dashboardDefaultPanelHeight;
              return ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _refresh(ref),
                        tooltip: 'Refresh (F5)',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  kpisAsync.when(
                    data: (kpis) => _KpiGrid(kpis: kpis),
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
                  if (isNarrow) ...<Widget>[
                    SizedBox(
                      height: panelHeight,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: recentSalesAsync.when(
                            data: (rows) => _RecentSalesTable(rows: rows),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Center(
                              child: Text('Failed to load recent sales.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: panelHeight,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: lowStockAsync.when(
                            data: (rows) => _LowStockPanel(rows: rows),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Center(
                              child: Text('Failed to load low stock data.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      height: panelHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: recentSalesAsync.when(
                                  data: (rows) => _RecentSalesTable(rows: rows),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Center(
                                    child: Text('Failed to load recent sales.'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: lowStockAsync.when(
                                  data: (rows) => _LowStockPanel(rows: rows),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Center(
                                    child: Text('Failed to load low stock data.'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final DashboardKpisEntity kpis;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      DashboardKpiCardWidget(
        label: 'Today Sales',
        value: FormattingHelpers.currencyPkr(kpis.todaySales),
        icon: Icons.payments_outlined,
        color: Colors.blue,
      ),
      DashboardKpiCardWidget(
        label: 'Today Profit',
        value: FormattingHelpers.currencyPkr(kpis.todayProfit),
        icon: Icons.trending_up,
        color: kpis.todayProfit >= 0 ? Colors.green : Colors.red,
      ),
      DashboardKpiCardWidget(
        label: 'Phones Sold Today',
        value: kpis.phonesSoldToday.toString(),
        icon: Icons.phone_android,
        color: Colors.indigo,
      ),
      DashboardKpiCardWidget(
        label: 'Accessories Sold Today',
        value: kpis.accessoriesSoldToday.toString(),
        icon: Icons.cable,
        color: Colors.teal,
      ),
      DashboardKpiCardWidget(
        label: 'Low Stock Count',
        value: kpis.lowStockCount.toString(),
        icon: Icons.warning_amber,
        color: kpis.lowStockCount > 0 ? Colors.orange : Colors.green,
      ),
      DashboardKpiCardWidget(
        label: 'Available Stock Count',
        value: kpis.availableStockCount.toString(),
        icon: Icons.inventory_2_outlined,
        color: Colors.deepPurple,
      ),
      DashboardKpiCardWidget(
        label: 'Pending Balances',
        value: FormattingHelpers.currencyPkr(kpis.pendingBalances),
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.red,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 750
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
            childAspectRatio: 2.3,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }
}

class _RecentSalesTable extends StatelessWidget {
  const _RecentSalesTable({required this.rows});

  final List<DashboardRecentSaleEntity> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Recent Sales', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No sales found.'))
              : AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Invoice')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Pending')),
                    DataColumn(label: Text('Payment')),
                  ],
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(row.invoiceNumber)),
                            DataCell(Text(
                                FormattingHelpers.dateYmdHm(row.saleDate))),
                            DataCell(Text(row.customerName)),
                            DataCell(
                                Text(FormattingHelpers.currencyPkr(row.total))),
                            DataCell(
                              Text(FormattingHelpers.currencyPkr(
                                  row.pendingAmount)),
                            ),
                            DataCell(Text(row.paymentMethod ?? '-')),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({required this.rows});

  final List<DashboardLowStockEntity> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Low Stock Warnings',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No low stock alerts.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text(row.productName),
                      subtitle: Text(
                        'Qty ${row.quantity} / Min ${row.minQuantity}${row.location == null ? '' : ' • ${row.location}'}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RefreshDashboardIntent extends Intent {
  const _RefreshDashboardIntent();
}
