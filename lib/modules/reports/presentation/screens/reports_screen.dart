import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_widget.dart';

bool hasNextReportsPageCandidate({
  required int resultsLength,
  required int pageSize,
}) {
  if (pageSize <= 0) {
    return false;
  }
  return resultsLength >= pageSize;
}

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
    final customerOptionsAsync = ref.watch(reportCustomerOptionsProvider);
    final productOptionsAsync = ref.watch(reportProductOptionsProvider);
    final canGoNextPage = _canGoNextPage(
      ref: ref,
      tab: tab,
      pageSize: filter.pageSize,
    );
    final customers = customerOptionsAsync.valueOrNull ?? const [];
    final products = productOptionsAsync.valueOrNull ?? const [];
    final customerOptionsError = customerOptionsAsync.whenOrNull(
      error: (error, _) => _errorMessage(error, 'Failed to load customers.'),
    );
    final productOptionsError = productOptionsAsync.whenOrNull(
      error: (error, _) => _errorMessage(error, 'Failed to load products.'),
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f5): _RefreshReportsIntent(),
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
                  customerOptionsError: customerOptionsError,
                  productOptionsError: productOptionsError,
                  onStartDate: (date) => ref
                      .read(reportFilterProvider.notifier)
                      .setStartDate(date),
                  onEndDate: (date) =>
                      ref.read(reportFilterProvider.notifier).setEndDate(date),
                  onCustomer: (value) => ref
                      .read(reportFilterProvider.notifier)
                      .setCustomerId(value),
                  onProduct: (value) => ref
                      .read(reportFilterProvider.notifier)
                      .setProductModelId(value),
                  onStatus: (value) =>
                      ref.read(reportFilterProvider.notifier).setStatus(value),
                  onPaymentMethod: (value) => ref
                      .read(reportFilterProvider.notifier)
                      .setPaymentMethod(value),
                  onClear: () =>
                      ref.read(reportFilterProvider.notifier).clearAll(),
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
                          onSelected: (_) => ref
                              .read(selectedReportsTabProvider.notifier)
                              .state = item,
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
                          : () => ref
                              .read(reportFilterProvider.notifier)
                              .previousPage(),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: canGoNextPage
                          ? () => ref.read(reportFilterProvider.notifier).nextPage()
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: filter.pageSize,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        ref
                            .read(reportFilterProvider.notifier)
                            .setPageSize(value);
                      },
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(
                            value: 25, child: Text('25 / page')),
                        DropdownMenuItem<int>(
                            value: 50, child: Text('50 / page')),
                        DropdownMenuItem<int>(
                            value: 100, child: Text('100 / page')),
                        DropdownMenuItem<int>(
                            value: 200, child: Text('200 / page')),
                      ],
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

  bool _canGoNextPage({
    required WidgetRef ref,
    required ReportsTab tab,
    required int pageSize,
  }) {
    switch (tab) {
      case ReportsTab.dailySales:
        final rows = ref.watch(dailySalesReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.dateRangeSales:
        final rows = ref.watch(dateRangeSalesReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.soldPhones:
        final rows = ref.watch(soldPhonesReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.currentStock:
        final rows = ref.watch(currentStockReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.customerBalance:
        final rows = ref.watch(customerBalanceReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.lowStock:
        final rows = ref.watch(lowStockReportProvider).valueOrNull;
        return rows != null &&
            hasNextReportsPageCandidate(
              resultsLength: rows.length,
              pageSize: pageSize,
            );
      case ReportsTab.profit:
        return false;
    }
  }

  String _errorMessage(Object error, String fallback) {
    if (error is AppError) {
      return error.message;
    }
    return fallback;
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent({required this.tab});

  final ReportsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (tab) {
      case ReportsTab.dailySales:
        return const _DailySalesView();
      case ReportsTab.dateRangeSales:
        return const _DateRangeSalesView();
      case ReportsTab.profit:
        return const _ProfitView();
      case ReportsTab.soldPhones:
        return const _SoldPhonesView();
      case ReportsTab.currentStock:
        return const _CurrentStockView();
      case ReportsTab.customerBalance:
        return const _CustomerBalanceView();
      case ReportsTab.lowStock:
        return const _LowStockView();
    }
  }
}

class _DailySalesView extends ConsumerWidget {
  const _DailySalesView();

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
                FormattingHelpers.currencyPkr(row.totalSales),
                FormattingHelpers.currencyPkr(row.totalProfit),
                row.phonesSold.toString(),
                row.accessoriesSold.toString(),
                FormattingHelpers.currencyPkr(row.pendingBalances),
              ],
            )
            .toList(growable: false);

        final totalSales =
            rows.fold<double>(0, (sum, row) => sum + row.totalSales);

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: ReportSummaryCardWidget(
                    label: 'Total Sales (page)',
                    value: FormattingHelpers.currencyPkr(totalSales),
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
      error: (_, __) =>
          const Center(child: Text('Failed to load daily sales report.')),
    );
  }
}

class _DateRangeSalesView extends ConsumerWidget {
  const _DateRangeSalesView();

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
                FormattingHelpers.dateYmd(row.saleDate),
                row.customerName,
                FormattingHelpers.currencyPkr(row.total),
                FormattingHelpers.currencyPkr(row.paidAmount),
                FormattingHelpers.currencyPkr(row.balance),
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
  const _ProfitView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profitReportProvider);

    return async.when(
      data: (report) => Row(
        children: <Widget>[
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Revenue',
              value: FormattingHelpers.currencyPkr(report.totalRevenue),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Cost',
              value: FormattingHelpers.currencyPkr(report.totalCost),
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Profit',
              value: FormattingHelpers.currencyPkr(report.totalProfit),
              color: report.totalProfit >= 0 ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReportSummaryCardWidget(
              label: 'Margin',
              value: '${FormattingHelpers.decimal(report.marginPercent)}%',
              color: Colors.indigo,
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Failed to load profit report.')),
    );
  }
}

class _SoldPhonesView extends ConsumerWidget {
  const _SoldPhonesView();

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
                FormattingHelpers.dateYmd(row.saleDate),
                row.productName,
                row.imei,
                row.customerName,
                FormattingHelpers.currencyPkr(row.salePrice),
                FormattingHelpers.currencyPkr(row.costPrice),
                FormattingHelpers.currencyPkr(row.profit),
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
      error: (_, __) =>
          const Center(child: Text('Failed to load sold phones report.')),
    );
  }
}

class _CurrentStockView extends ConsumerWidget {
  const _CurrentStockView();

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
                FormattingHelpers.currencyPkr(row.unitCost),
                FormattingHelpers.currencyPkr(row.unitPrice),
                FormattingHelpers.currencyPkr(row.stockValue),
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
      error: (_, __) =>
          const Center(child: Text('Failed to load current stock report.')),
    );
  }
}

class _CustomerBalanceView extends ConsumerWidget {
  const _CustomerBalanceView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerBalanceReportProvider);

    return async.when(
      data: (rows) {
        final tableRows = rows
            .map(
              (row) => <String>[
                row.customerName,
                FormattingHelpers.currencyPkr(row.totalSales),
                FormattingHelpers.currencyPkr(row.totalPaid),
                FormattingHelpers.currencyPkr(row.pendingBalance),
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
  const _LowStockView();

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
      error: (_, __) =>
          const Center(child: Text('Failed to load low stock report.')),
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
