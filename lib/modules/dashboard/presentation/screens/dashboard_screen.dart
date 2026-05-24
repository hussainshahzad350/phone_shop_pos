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
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

const double _dashboardNarrowWidthBreakpoint = 1220;

double _dashboardPanelHeightFor(double viewportHeight) {
  if (viewportHeight < 760) {
    return 280;
  }
  if (viewportHeight < 900) {
    return 340;
  }
  if (viewportHeight < 1080) {
    return 400;
  }
  return 480;
}

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
                  _dashboardPanelHeightFor(constraints.maxHeight);
              return ListView(
                padding: const EdgeInsets.all(10),
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _refresh(ref),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
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
                            flex: 5,
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
                            flex: 3,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: lowStockAsync.when(
                                  data: (rows) => _LowStockPanel(rows: rows),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Center(
                                    child:
                                        Text('Failed to load low stock data.'),
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
        label: 'Total Stock Worth',
        value: FormattingHelpers.currencyPkr(kpis.totalStockWorth),
        icon: Icons.savings_outlined,
        color: Colors.amber,
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = _DashboardRecentSalesLayout.fromWidth(
                      MediaQuery.sizeOf(context).width,
                    );
                    final visibleColumns = _visibleColumns();
                    return Column(
                      children: <Widget>[
                        Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: visibleColumns
                                .map(
                                  (column) => _headerCell(
                                    _columnLabel(column),
                                    width: layout.valueWidth(column),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return SizedBox(
                                height: layout.dataRowMinHeight,
                                child: Row(
                                  children: visibleColumns
                                      .map(
                                        (column) => _buildRowCell(
                                          context: context,
                                          row: row,
                                          column: column,
                                          layout: layout,
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openInvoiceDialog(
    BuildContext context,
    DashboardRecentSaleEntity row,
  ) async {
    final saleId = row.saleId;
    if (saleId == null || saleId.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _DashboardSalesInvoiceDialog(saleId: saleId),
    );
  }

  List<_DashboardRecentSalesColumn> _visibleColumns() {
    return const <_DashboardRecentSalesColumn>[
      _DashboardRecentSalesColumn.invoice,
      _DashboardRecentSalesColumn.date,
      _DashboardRecentSalesColumn.total,
      _DashboardRecentSalesColumn.customer,
      _DashboardRecentSalesColumn.view,
    ];
  }

  String _columnLabel(_DashboardRecentSalesColumn column) {
    switch (column) {
      case _DashboardRecentSalesColumn.invoice:
        return 'Invoice';
      case _DashboardRecentSalesColumn.date:
        return 'Date';
      case _DashboardRecentSalesColumn.customer:
        return 'Customer';
      case _DashboardRecentSalesColumn.total:
        return 'Total';
      case _DashboardRecentSalesColumn.view:
        return 'Open';
    }
  }

  Widget _buildRowCell({
    required BuildContext context,
    required DashboardRecentSaleEntity row,
    required _DashboardRecentSalesColumn column,
    required _DashboardRecentSalesLayout layout,
  }) {
    switch (column) {
      case _DashboardRecentSalesColumn.invoice:
        return _valueCell(
          row.invoiceNumber,
          width: layout.valueWidth(column),
        );
      case _DashboardRecentSalesColumn.date:
        return _valueCell(
          FormattingHelpers.dateYmdHm(row.saleDate),
          width: layout.valueWidth(column),
        );
      case _DashboardRecentSalesColumn.customer:
        return _valueCell(
          row.customerName,
          width: layout.valueWidth(column),
        );
      case _DashboardRecentSalesColumn.total:
        return _valueCell(
          FormattingHelpers.currencyPkr(row.total),
          width: layout.valueWidth(column),
        );
      case _DashboardRecentSalesColumn.view:
        return SizedBox(
          width: layout.valueWidth(column),
          child: Align(
            alignment: Alignment.center,
            child: IconButton(
              tooltip: 'View invoice',
              onPressed: (row.saleId == null || row.saleId!.isEmpty)
                  ? null
                  : () => _openInvoiceDialog(context, row),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
          ),
        );
    }
  }

  Widget _headerCell(String text, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _valueCell(
    String text, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

enum _DashboardRecentSalesColumn {
  invoice,
  date,
  customer,
  total,
  view,
}

class _DashboardRecentSalesLayout {
  const _DashboardRecentSalesLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.showMediumColumns,
    required this.showCompactColumns,
    required this.isWideDesktop,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showMediumColumns;
  final bool showCompactColumns;
  final bool isWideDesktop;

  factory _DashboardRecentSalesLayout.fromWidth(double width) {
    if (width >= 1400) {
      return const _DashboardRecentSalesLayout(
        columnSpacing: 16,
        dataRowMinHeight: 50,
        dataRowMaxHeight: 58,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1080) {
      return const _DashboardRecentSalesLayout(
        columnSpacing: 14,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return const _DashboardRecentSalesLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }

  double valueWidth(_DashboardRecentSalesColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _DashboardRecentSalesColumn.invoice:
          return 145;
        case _DashboardRecentSalesColumn.date:
          return 170;
        case _DashboardRecentSalesColumn.customer:
          return 250;
        case _DashboardRecentSalesColumn.total:
          return 120;
        case _DashboardRecentSalesColumn.view:
          return 52;
      }
    }

    switch (column) {
      case _DashboardRecentSalesColumn.invoice:
        return 140;
      case _DashboardRecentSalesColumn.date:
        return 165;
      case _DashboardRecentSalesColumn.customer:
        return 230;
      case _DashboardRecentSalesColumn.total:
        return 126;
      case _DashboardRecentSalesColumn.view:
        return 52;
    }
  }
}

class _DashboardSalesInvoiceDialog extends ConsumerWidget {
  const _DashboardSalesInvoiceDialog({required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(salesInvoiceDetailProvider(saleId));
    return AlertDialog(
      title: const Text('Invoice Details'),
      content: SizedBox(
        width: 960,
        height: 500,
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Invoice not found.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Invoice: ${detail.sale.invoiceNumber}'),
                    Text(
                        'Date: ${FormattingHelpers.dateYmd(detail.sale.saleDate)}'),
                    Text('Customer: ${detail.sale.customerName}'),
                    Text(
                        'Total: ${FormattingHelpers.currencyPkr(detail.sale.total)}'),
                    Text(
                        'Paid: ${FormattingHelpers.currencyPkr(detail.sale.paidAmount)}'),
                    Text(
                      'Remaining: ${FormattingHelpers.currencyPkr(detail.sale.remainingBalance)}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if ((detail.notes ?? '').isNotEmpty) ...<Widget>[
                  Text('Notes: ${detail.notes}'),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: AppDataTable(
                    showCheckboxColumn: false,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('IMEI')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Line Total')),
                      DataColumn(label: Text('Returned')),
                    ],
                    rows: detail.items
                        .map(
                          (item) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(item.productName)),
                              DataCell(Text(item.imei ?? '-')),
                              DataCell(Text(item.quantity.toString())),
                              DataCell(
                                Text(FormattingHelpers.currencyPkr(
                                    item.unitPrice)),
                              ),
                              DataCell(
                                Text(FormattingHelpers.currencyPkr(
                                    item.lineTotal)),
                              ),
                              DataCell(Text(item.returnedQty.toString())),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Failed to load invoice details.'),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
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
