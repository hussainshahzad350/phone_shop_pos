import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_widget.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(dailySalesReportProvider);
    ref.invalidate(dateRangeSalesReportProvider);
    ref.invalidate(profitReportProvider);
    ref.invalidate(soldPhonesReportProvider);
    ref.invalidate(currentStockReportProvider);
    ref.invalidate(customerBalanceReportProvider);
    ref.invalidate(lowStockReportProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedReportsTabProvider);
    final filter = ref.watch(reportFilterProvider);
    final customers = ref.watch(reportCustomerOptionsProvider).value ?? const [];
    final products = ref.watch(reportProductOptionsProvider).value ?? const [];

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.f5): const _RefreshReportsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RefreshReportsIntent: CallbackAction<_RefreshReportsIntent>(
            onInvoke: (_) {
              _refreshAll(ref);
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Reports',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _refreshAll(ref),
                      tooltip: 'Refresh (F5)',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ReportFilterBarWidget(
                  filter: filter,
                  customerOptions: customers,
                  productOptions: products,
                  onStartDate: (date) =>
                      ref.read(reportFilterProvider.notifier).setStartDate(date),
                  onEndDate: (date) =>
                      ref.read(reportFilterProvider.notifier).setEndDate(date),
                  onCustomer: (value) =>
                      ref.read(reportFilterProvider.notifier).setCustomerId(value),
                  onProduct: (value) =>
                      ref.read(reportFilterProvider.notifier).setProductModelId(value),
                  onStatus: (value) =>
                      ref.read(reportFilterProvider.notifier).setStatus(value),
                  onPaymentMethod: (value) => ref
                      .read(reportFilterProvider.notifier)
                      .setPaymentMethod(value),
                  onClear: () => ref.read(reportFilterProvider.notifier).clearAll(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReportsTab.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(_tabLabel(item)),
                          selected: item == tab,
                          onSelected: (_) =>
                              ref.read(selectedReportsTabProvider.notifier).state = item,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ReportContent(tab: tab),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: filter.page <= 1
                          ? null
                          : () =>
                              ref.read(reportFilterProvider.notifier).previousPage(),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(reportFilterProvider.notifier).nextPage(),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                    const SizedBox(width: 12),
                    Text('Page ${filter.page}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent({required this.tab});

  final ReportsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (tab) {
      case ReportsTab.dailySales:
        return _DailySalesView();
      case ReportsTab.dateRangeSales:
        return _DateRangeSalesView();
      case ReportsTab.profit:
        return _ProfitView();
      case ReportsTab.soldPhones:
        return _SoldPhonesView();
      case ReportsTab.currentStock:
        return _CurrentStockView();
      case ReportsTab.customerBalance:
        return _CustomerBalanceView();
      case ReportsTab.lowStock:
        return _LowStockView();
    }
  }
}

class _DailySalesView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailySalesReportProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.day,
                row.invoiceCount.toString(),
                _currency(row.totalSales),
                _currency(row.totalProfit),
                row.phonesSold.toString(),
                row.accessoriesSold.toString(),
                _currency(row.pendingBalances),
              ],
            )
            .toList(growable: false);

        final totalSales = rows.fold<double>(0, (sum, row) => sum + row.totalSales);

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: ReportSummaryCardWidget(
                    label: 'Total Sales (page)',
                    value: _currency(totalSales),
                  ),
                ),
                const SizedBox(width: 8),
                ReportExportActionWidget(
                  title: 'Daily Sales Report',
                  fileBaseName: 'daily_sales_report',
                  headers: const <String>[
                    'Day',
                    'Invoices',
                    'Sales',
                    'Profit',
                    'Phones',
                    'Accessories',
                    'Pending',
                  ],
                  rows: tableRows,
                  csvExportService: csvService,
                  printableReportService: printableService,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ReportTableWidget(
                    columns: const <ReportTableColumn>[
                      ReportTableColumn(label: 'Day'),
                      ReportTableColumn(label: 'Invoices'),
                      ReportTableColumn(label: 'Sales'),
                      ReportTableColumn(label: 'Profit'),
                      ReportTableColumn(label: 'Phones'),
                      ReportTableColumn(label: 'Accessories'),
                      ReportTableColumn(label: 'Pending'),
                    ],
                    rows: tableRows,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load daily sales report.')),
    );
  }
}

class _DateRangeSalesView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dateRangeSalesReportProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.invoiceNumber,
                _date(row.saleDate),
                row.customerName,
                _currency(row.total),
                _currency(row.paidAmount),
                _currency(row.balance),
                row.paymentMethod ?? '-',
                row.status,
              ],
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: ReportExportActionWidget(
                    title: 'Date Range Sales Report',
                    fileBaseName: 'date_range_sales_report',
                    headers: const <String>[
                      'Invoice',
                      'Date',
                      'Customer',
                      'Total',
                      'Paid',
                      'Balance',
                      'Payment',
                      'Status',
                    ],
                    rows: tableRows,
                    csvExportService: csvService,
                    printableReportService: printableService,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReportTableWidget(
                    columns: const <ReportTableColumn>[
                      ReportTableColumn(label: 'Invoice'),
                      ReportTableColumn(label: 'Date'),
                      ReportTableColumn(label: 'Customer'),
                      ReportTableColumn(label: 'Total'),
                      ReportTableColumn(label: 'Paid'),
                      ReportTableColumn(label: 'Balance'),
                      ReportTableColumn(label: 'Payment'),
                      ReportTableColumn(label: 'Status'),
                    ],
                    rows: tableRows,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load date range sales report.')),
    );
  }
}

class _ProfitView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profitReportProvider);

    return async.when(
      data: (report) => Row(
        children: <Widget>[
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Revenue',
              value: _currency(report.totalRevenue),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Cost',
              value: _currency(report.totalCost),
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Profit',
              value: _currency(report.totalProfit),
              color: report.totalProfit >= 0 ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Margin',
              value: '${report.marginPercent.toStringAsFixed(2)}%',
              color: Colors.indigo,
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load profit report.')),
    );
  }
}

class _SoldPhonesView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(soldPhonesReportProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.invoiceNumber,
                _date(row.saleDate),
                row.productName,
                row.imei,
                row.customerName,
                _currency(row.salePrice),
                _currency(row.costPrice),
                _currency(row.profit),
              ],
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: ReportExportActionWidget(
                    title: 'Sold Phones Report',
                    fileBaseName: 'sold_phones_report',
                    headers: const <String>[
                      'Invoice',
                      'Date',
                      'Product',
                      'IMEI',
                      'Customer',
                      'Sale Price',
                      'Cost Price',
                      'Profit',
                    ],
                    rows: tableRows,
                    csvExportService: csvService,
                    printableReportService: printableService,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReportTableWidget(
                    columns: const <ReportTableColumn>[
                      ReportTableColumn(label: 'Invoice'),
                      ReportTableColumn(label: 'Date'),
                      ReportTableColumn(label: 'Product'),
                      ReportTableColumn(label: 'IMEI'),
                      ReportTableColumn(label: 'Customer'),
                      ReportTableColumn(label: 'Sale'),
                      ReportTableColumn(label: 'Cost'),
                      ReportTableColumn(label: 'Profit'),
                    ],
                    rows: tableRows,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load sold phones report.')),
    );
  }
}

class _CurrentStockView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentStockReportProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.productName,
                row.category,
                row.availableQuantity.toString(),
                row.minQuantity.toString(),
                _currency(row.unitCost),
                _currency(row.unitPrice),
                _currency(row.stockValue),
                row.isLowStock ? 'Low' : 'OK',
              ],
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ReportTableWidget(
              columns: const <ReportTableColumn>[
                ReportTableColumn(label: 'Product'),
                ReportTableColumn(label: 'Category'),
                ReportTableColumn(label: 'Available'),
                ReportTableColumn(label: 'Min'),
                ReportTableColumn(label: 'Unit Cost'),
                ReportTableColumn(label: 'Unit Price'),
                ReportTableColumn(label: 'Stock Value'),
                ReportTableColumn(label: 'Status'),
              ],
              rows: tableRows,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load current stock report.')),
    );
  }
}

class _CustomerBalanceView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerBalanceReportProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.customerName,
                _currency(row.totalSales),
                _currency(row.totalPaid),
                _currency(row.pendingBalance),
              ],
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ReportTableWidget(
              columns: const <ReportTableColumn>[
                ReportTableColumn(label: 'Customer'),
                ReportTableColumn(label: 'Total Sales'),
                ReportTableColumn(label: 'Total Paid'),
                ReportTableColumn(label: 'Pending Balance'),
              ],
              rows: tableRows,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load customer balance report.')),
    );
  }
}

class _LowStockView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lowStockReportProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.productName,
                row.quantity.toString(),
                row.minQuantity.toString(),
                row.location ?? '-',
              ],
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ReportTableWidget(
              columns: const <ReportTableColumn>[
                ReportTableColumn(label: 'Product'),
                ReportTableColumn(label: 'Quantity'),
                ReportTableColumn(label: 'Min Quantity'),
                ReportTableColumn(label: 'Location'),
              ],
              rows: tableRows,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load low stock report.')),
    );
  }
}

class _RefreshReportsIntent extends Intent {
  const _RefreshReportsIntent();
}

String _tabLabel(ReportsTab tab) {
  switch (tab) {
    case ReportsTab.dailySales:
      return 'Daily Sales';
    case ReportsTab.dateRangeSales:
      return 'Date Range Sales';
    case ReportsTab.profit:
      return 'Profit';
    case ReportsTab.soldPhones:
      return 'Sold Phones';
    case ReportsTab.currentStock:
      return 'Current Stock';
    case ReportsTab.customerBalance:
      return 'Customer Balance';
    case ReportsTab.lowStock:
      return 'Low Stock';
  }
}

String _currency(double amount) => 'PKR ${amount.toStringAsFixed(2)}';

String _date(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
