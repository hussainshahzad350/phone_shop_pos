import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';

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
    ref.invalidate(salesHistoryRowsProvider);
    ref.invalidate(purchaseHistoryRowsProvider);
    ref.invalidate(supplierLedgerRowsProvider);
    ref.invalidate(cashLedgerRowsProvider);
    ref.invalidate(expensesRowsProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(stockAdjustmentHistoryProvider);
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
    final customers = customerOptionsAsync.when(
      data: (value) => value,
      loading: () => const <MapEntry<String, String>>[],
      error: (_, __) => const <MapEntry<String, String>>[],
    );
    final products = productOptionsAsync.when(
      data: (value) => value,
      loading: () => const <MapEntry<String, String>>[],
      error: (_, __) => const <MapEntry<String, String>>[],
    );
    final customerOptionsError = customerOptionsAsync.whenOrNull(
      error: (error, _) => _errorMessage(error, 'Failed to load customers.'),
    );
    final productOptionsError = productOptionsAsync.whenOrNull(
      error: (error, _) => _errorMessage(error, 'Failed to load products.'),
    );
    final customerOptionsLoading = customerOptionsAsync.isLoading;
    final productOptionsLoading = productOptionsAsync.isLoading;

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
                if (_usesLegacyFilters(tab)) ...<Widget>[
                  ReportFilterBarWidget(
                    filter: filter,
                    customerOptions: customers,
                    productOptions: products,
                    customerOptionsError: customerOptionsError,
                    productOptionsError: productOptionsError,
                    customerOptionsLoading: customerOptionsLoading,
                    productOptionsLoading: productOptionsLoading,
                    onRetryCustomerOptions: () =>
                        ref.invalidate(reportCustomerOptionsProvider),
                    onRetryProductOptions: () =>
                        ref.invalidate(reportProductOptionsProvider),
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
                ],
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
                if (_usesLegacyFilters(tab)) ...<Widget>[
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
      case ReportsTab.salesHistory:
      case ReportsTab.creditCollection:
      case ReportsTab.purchaseHistory:
      case ReportsTab.supplierLedger:
      case ReportsTab.cashLedger:
      case ReportsTab.expenses:
        return false;
    }
  }

  bool _usesLegacyFilters(ReportsTab tab) {
    return tab == ReportsTab.dailySales ||
        tab == ReportsTab.dateRangeSales ||
        tab == ReportsTab.profit ||
        tab == ReportsTab.soldPhones ||
        tab == ReportsTab.currentStock ||
        tab == ReportsTab.customerBalance ||
        tab == ReportsTab.lowStock;
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
      case ReportsTab.salesHistory:
        return const _SalesHistoryView();
      case ReportsTab.creditCollection:
        return const _CreditCollectionView();
      case ReportsTab.purchaseHistory:
        return const _PurchaseHistoryView();
      case ReportsTab.supplierLedger:
        return const _SupplierLedgerView();
      case ReportsTab.cashLedger:
        return const _CashLedgerView();
      case ReportsTab.expenses:
        return const _ExpensesView();
    }
  }
}

class _ReportErrorView extends StatelessWidget {
  const _ReportErrorView({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final details = error is AppError ? (error as AppError).message : '$error';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(message),
          const SizedBox(height: 6),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load daily sales report.',
        error: error,
        onRetry: () => ref.invalidate(dailySalesReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load date range sales report.',
        error: error,
        onRetry: () => ref.invalidate(dateRangeSalesReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load profit report.',
        error: error,
        onRetry: () => ref.invalidate(profitReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load sold phones report.',
        error: error,
        onRetry: () => ref.invalidate(soldPhonesReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load current stock report.',
        error: error,
        onRetry: () => ref.invalidate(currentStockReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load customer balance report.',
        error: error,
        onRetry: () => ref.invalidate(customerBalanceReportProvider),
      ),
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
      error: (error, _) => _ReportErrorView(
        message: 'Failed to load low stock report.',
        error: error,
        onRetry: () => ref.invalidate(lowStockReportProvider),
      ),
    );
  }
}

class _SalesHistoryView extends ConsumerWidget {
  const _SalesHistoryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(salesHistoryRowsProvider);
    final pendingOnly = ref.watch(salesHistoryPendingOnlyProvider);

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Invoice #',
                    ),
                    onChanged: (value) =>
                        ref.read(salesHistoryInvoiceQueryProvider.notifier).state = value,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Customer Name / ID',
                    ),
                    onChanged: (value) =>
                        ref.read(salesHistoryCustomerQueryProvider.notifier).state = value,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(salesHistoryStartDateProvider) ?? DateTime.now(),
                    );
                    ref.read(salesHistoryStartDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    ref.watch(salesHistoryStartDateProvider) == null
                        ? 'Start Date'
                        : FormattingHelpers.dateYmd(ref.watch(salesHistoryStartDateProvider)!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(salesHistoryEndDateProvider) ?? DateTime.now(),
                    );
                    ref.read(salesHistoryEndDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    ref.watch(salesHistoryEndDateProvider) == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(ref.watch(salesHistoryEndDateProvider)!),
                  ),
                ),
                FilterChip(
                  label: const Text('Pending only'),
                  selected: pendingOnly,
                  onSelected: (value) =>
                      ref.read(salesHistoryPendingOnlyProvider.notifier).state = value,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppDataTable(
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Invoice')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Paid')),
                      DataColumn(label: Text('Remaining')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: rows.map((row) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(row.invoiceNumber)),
                          DataCell(Text(FormattingHelpers.dateYmd(row.saleDate))),
                          DataCell(Text(row.customerName)),
                          DataCell(Text(FormattingHelpers.currencyPkr(row.total))),
                          DataCell(Text(FormattingHelpers.currencyPkr(row.paidAmount))),
                          DataCell(Text(FormattingHelpers.currencyPkr(row.remainingBalance))),
                          DataCell(Text(row.isPaid ? 'Paid' : 'Pending')),
                          DataCell(
                            Wrap(
                              spacing: 4,
                              children: <Widget>[
                                OutlinedButton(
                                  onPressed: () => _showInvoiceDialog(
                                    context: context,
                                    saleId: row.saleId,
                                  ),
                                  child: const Text('Open'),
                                ),
                                if (row.printJobId != null)
                                  FilledButton.tonal(
                                    onPressed: () => _reprint(
                                      ref: ref,
                                      jobId: row.printJobId!,
                                    ),
                                    child: const Text('Reprint'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load sales history.',
              error: error,
              onRetry: () => ref.invalidate(salesHistoryRowsProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showInvoiceDialog({
    required BuildContext context,
    required String saleId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SalesInvoiceDialog(saleId: saleId),
    );
  }

  Future<void> _reprint({
    required WidgetRef ref,
    required String jobId,
  }) async {
    final result = await ref.read(invoicePrintQueueProvider.notifier).printJob(
          jobId: jobId,
          paperSize: InvoicePaperSize.thermal80,
        );
    if (result.isSuccess) {
      AppNotifier.success('Receipt sent to spool again.');
      return;
    }
    AppNotifier.error(result.asFailure!.error.message);
  }
}

class _CreditCollectionView extends ConsumerWidget {
  const _CreditCollectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(salesHistoryRowsProvider);
    return rowsAsync.when(
      data: (rows) {
        final pendingRows = rows.where((row) => !row.isPaid).toList(growable: false);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AppDataTable(
              emptyMessage: 'No pending credit sales.',
              columns: const <DataColumn>[
                DataColumn(label: Text('Invoice')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Outstanding')),
                DataColumn(label: Text('Collect')),
              ],
              rows: pendingRows.map((row) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(row.invoiceNumber)),
                    DataCell(Text(row.customerName)),
                    DataCell(Text(FormattingHelpers.currencyPkr(row.total))),
                    DataCell(Text(FormattingHelpers.currencyPkr(row.paidAmount))),
                    DataCell(Text(FormattingHelpers.currencyPkr(row.remainingBalance))),
                    DataCell(
                      FilledButton(
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (context) => _CollectPaymentDialog(sale: row),
                          );
                        },
                        child: const Text('Collect'),
                      ),
                    ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => _ReportErrorView(
        message: 'Failed to load credit sales.',
        error: error,
        onRetry: () => ref.invalidate(salesHistoryRowsProvider),
      ),
    );
  }
}

class _PurchaseHistoryView extends ConsumerWidget {
  const _PurchaseHistoryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(purchaseHistoryRowsProvider);
    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Supplier',
                    ),
                    onChanged: (value) =>
                        ref.read(purchaseHistorySupplierQueryProvider.notifier).state = value,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate:
                          ref.read(purchaseHistoryStartDateProvider) ?? DateTime.now(),
                    );
                    ref.read(purchaseHistoryStartDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    ref.watch(purchaseHistoryStartDateProvider) == null
                        ? 'Start Date'
                        : FormattingHelpers.dateYmd(ref.watch(purchaseHistoryStartDateProvider)!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate:
                          ref.read(purchaseHistoryEndDateProvider) ?? DateTime.now(),
                    );
                    ref.read(purchaseHistoryEndDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    ref.watch(purchaseHistoryEndDateProvider) == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(ref.watch(purchaseHistoryEndDateProvider)!),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) => Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Invoice')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Paid')),
                    DataColumn(label: Text('Balance')),
                    DataColumn(label: Text('Details')),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(FormattingHelpers.dateYmd(row.purchaseDate))),
                        DataCell(Text(row.supplierName)),
                        DataCell(Text(row.invoiceNumber ?? '-')),
                        DataCell(Text(FormattingHelpers.currencyPkr(row.total))),
                        DataCell(Text(FormattingHelpers.currencyPkr(row.paidAmount))),
                        DataCell(Text(FormattingHelpers.currencyPkr(row.remainingBalance))),
                        DataCell(
                          OutlinedButton(
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (context) => _PurchaseDetailDialog(
                                  purchaseId: row.purchaseId,
                                ),
                              );
                            },
                            child: const Text('Open'),
                          ),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load purchase history.',
              error: error,
              onRetry: () => ref.invalidate(purchaseHistoryRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupplierLedgerView extends ConsumerWidget {
  const _SupplierLedgerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(supplierLedgerRowsProvider);
    return rowsAsync.when(
      data: (rows) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AppDataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Purchases')),
              DataColumn(label: Text('Total Purchases')),
              DataColumn(label: Text('Total Paid')),
              DataColumn(label: Text('Pending')),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(row.supplierName)),
                  DataCell(Text(row.purchaseCount.toString())),
                  DataCell(Text(FormattingHelpers.currencyPkr(row.totalPurchases))),
                  DataCell(Text(FormattingHelpers.currencyPkr(row.totalPaid))),
                  DataCell(Text(FormattingHelpers.currencyPkr(row.pendingAmount))),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => _ReportErrorView(
        message: 'Failed to load supplier ledger.',
        error: error,
        onRetry: () => ref.invalidate(supplierLedgerRowsProvider),
      ),
    );
  }
}

class _CashLedgerView extends ConsumerWidget {
  const _CashLedgerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(cashLedgerRowsProvider);
    final startDate = ref.watch(cashLedgerStartDateProvider);
    final endDate = ref.watch(cashLedgerEndDateProvider);
    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(cashLedgerStartDateProvider) ?? DateTime.now(),
                    );
                    ref.read(cashLedgerStartDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    startDate == null
                        ? 'Start Date'
                        : FormattingHelpers.dateYmd(startDate),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(cashLedgerEndDateProvider) ?? DateTime.now(),
                    );
                    ref.read(cashLedgerEndDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    endDate == null ? 'End Date' : FormattingHelpers.dateYmd(endDate),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(cashLedgerStartDateProvider.notifier).state = null;
                    ref.read(cashLedgerEndDateProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Dates'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) => Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Cash Flow components: Inflows (Cash Sales + Cash Collections), Outflows (Purchases Paid + Expenses)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This report shows cash movement only, not physical drawer cash-on-hand.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AppDataTable(
                        emptyMessage: 'No cash flow rows in selected date range.',
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Day')),
                          DataColumn(label: Text('Cash Sales In')),
                          DataColumn(label: Text('Collections In')),
                          DataColumn(label: Text('Total Cash In')),
                          DataColumn(label: Text('Purchases Paid Out')),
                          DataColumn(label: Text('Expenses Out')),
                          DataColumn(label: Text('Total Cash Out')),
                          DataColumn(label: Text('Net Cash')),
                        ],
                        rows: rows.map((row) {
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(row.day)),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.cashSalesIn))),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.cashCollectionsIn))),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.totalCashIn))),
                              DataCell(
                                Text(FormattingHelpers.currencyPkr(row.purchasePaymentsOut)),
                              ),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.expensesOut))),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.totalCashOut))),
                              DataCell(Text(FormattingHelpers.currencyPkr(row.netCash))),
                            ],
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load cash flow.',
              error: error,
              onRetry: () => ref.invalidate(cashLedgerRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpensesView extends ConsumerWidget {
  const _ExpensesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(expensesRowsProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final startDate = ref.watch(expensesStartDateProvider);
    final endDate = ref.watch(expensesEndDateProvider);
    final categoryFilter = ref.watch(expensesCategoryProvider);

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _ExpenseFormDialog(),
                    );
                    if (saved == true) {
                      ref.invalidate(expensesRowsProvider);
                      ref.invalidate(expenseCategoriesProvider);
                      ref.invalidate(cashLedgerRowsProvider);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate:
                          ref.read(expensesStartDateProvider) ?? DateTime.now(),
                    );
                    ref.read(expensesStartDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    startDate == null
                        ? 'Start Date'
                        : FormattingHelpers.dateYmd(startDate),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate:
                          ref.read(expensesEndDateProvider) ?? DateTime.now(),
                    );
                    ref.read(expensesEndDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    endDate == null ? 'End Date' : FormattingHelpers.dateYmd(endDate),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: categoriesAsync.when(
                    data: (categories) {
                      final selectedValue = categoryFilter.trim().isEmpty
                          ? ''
                          : categoryFilter.trim();
                      final items = <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All Categories'),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ];
                      return DropdownButtonFormField<String>(
                        value: items.any((item) => item.value == selectedValue)
                            ? selectedValue
                            : '',
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          labelText: 'Category',
                        ),
                        items: items,
                        onChanged: (value) => ref
                            .read(expensesCategoryProvider.notifier)
                            .state = value ?? '',
                      );
                    },
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'Category',
                      ),
                      onChanged: (value) =>
                          ref.read(expensesCategoryProvider.notifier).state = value,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(expensesStartDateProvider.notifier).state = null;
                    ref.read(expensesEndDateProvider.notifier).state = null;
                    ref.read(expensesCategoryProvider.notifier).state = '';
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) => Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppDataTable(
                  emptyMessage: 'No expenses found.',
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Notes')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(FormattingHelpers.dateYmd(row.expenseDate))),
                        DataCell(Text(row.category)),
                        DataCell(Text(FormattingHelpers.currencyPkr(row.amount))),
                        DataCell(Text(row.notes ?? '-')),
                        DataCell(
                          Wrap(
                            spacing: 6,
                            children: <Widget>[
                              OutlinedButton(
                                onPressed: () async {
                                  final saved = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        _ExpenseFormDialog(initialExpense: row),
                                  );
                                  if (saved == true) {
                                    ref.invalidate(expensesRowsProvider);
                                    ref.invalidate(expenseCategoriesProvider);
                                    ref.invalidate(cashLedgerRowsProvider);
                                  }
                                },
                                child: const Text('Edit'),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete Expense'),
                                      content: const Text(
                                        'This will hide the expense from reports. Continue?',
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext)
                                              .pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) {
                                    return;
                                  }
                                  final repository =
                                      await ref.read(expenseRepositoryProvider.future);
                                  final result = await repository.deleteExpense(row.id);
                                  if (result.isFailure) {
                                    AppNotifier.error(
                                      result.asFailure!.error.message,
                                    );
                                    return;
                                  }
                                  ref.invalidate(expensesRowsProvider);
                                  ref.invalidate(expenseCategoriesProvider);
                                  ref.invalidate(cashLedgerRowsProvider);
                                  AppNotifier.success('Expense deleted.');
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load expenses.',
              error: error,
              onRetry: () {
                ref.invalidate(expensesRowsProvider);
                ref.invalidate(expenseCategoriesProvider);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseFormDialog extends ConsumerStatefulWidget {
  const _ExpenseFormDialog({this.initialExpense});

  final ExpenseEntity? initialExpense;

  @override
  ConsumerState<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<_ExpenseFormDialog> {
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late DateTime _expenseDate;
  bool _isSubmitting = false;

  bool get _isEdit => widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExpense;
    _expenseDate = initial?.expenseDate.toLocal() ?? DateTime.now();
    _categoryController =
        TextEditingController(text: initial == null ? '' : initial.category);
    _amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2),
    );
    _notesController =
        TextEditingController(text: initial == null ? '' : initial.notes ?? '');
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _expenseDate,
                      );
                      if (picked == null) {
                        return;
                      }
                      setState(() => _expenseDate = picked);
                    },
              icon: const Icon(Icons.calendar_today),
              label: Text(FormattingHelpers.dateYmd(_expenseDate)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Category',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      AppNotifier.error('Category is required.');
      return;
    }
    final amount = FormattingHelpers.parseLocaleDecimal(_amountController.text);
    if (amount.isNaN) {
      AppNotifier.error('Please enter a valid amount.');
      return;
    }
    if (amount < 0) {
      AppNotifier.error('Amount cannot be negative.');
      return;
    }
    final notesError =
        NotesSafety.validate(_notesController.text, fieldLabel: 'Expense notes');
    if (notesError != null) {
      AppNotifier.error(notesError);
      return;
    }

    setState(() => _isSubmitting = true);
    final repository = await ref.read(expenseRepositoryProvider.future);
    final now = DateTimeHelpers.nowUtc();
    final existing = widget.initialExpense;
    final payload = ExpenseEntity(
      id: existing?.id ?? IdHelpers.newId(prefix: 'exp'),
      expenseDate: DateTime.utc(
        _expenseDate.year,
        _expenseDate.month,
        _expenseDate.day,
      ),
      category: category,
      amount: amount,
      notes: _notesController.text,
      createdAt: existing?.createdAt ?? now,
      updatedAt: existing == null ? null : now,
    );

    final result = existing == null
        ? await repository.addExpense(payload)
        : await repository.updateExpense(payload);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success(existing == null ? 'Expense added.' : 'Expense updated.');
    Navigator.of(context).pop(true);
  }
}

class _SalesInvoiceDialog extends ConsumerWidget {
  const _SalesInvoiceDialog({required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(salesInvoiceDetailProvider(saleId));
    return AlertDialog(
      title: const Text('Invoice Details'),
      content: SizedBox(
        width: 980,
        height: 520,
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Invoice not found.');
            }
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Invoice: ${detail.sale.invoiceNumber}'),
                    Text('Date: ${FormattingHelpers.dateYmd(detail.sale.saleDate)}'),
                    Text('Customer: ${detail.sale.customerName}'),
                    Text('Total: ${FormattingHelpers.currencyPkr(detail.sale.total)}'),
                    Text('Paid: ${FormattingHelpers.currencyPkr(detail.sale.paidAmount)}'),
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
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('IMEI')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Line Total')),
                      DataColumn(label: Text('Returned')),
                      DataColumn(label: Text('Return Action')),
                    ],
                    rows: detail.items.map((item) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(item.productName)),
                          DataCell(Text(item.imei ?? '-')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(FormattingHelpers.currencyPkr(item.unitPrice))),
                          DataCell(Text(FormattingHelpers.currencyPkr(item.lineTotal))),
                          DataCell(Text(item.returnedQty.toString())),
                          DataCell(
                            item.returnableQty <= 0
                                ? const Text('Done')
                                : FilledButton.tonal(
                                    onPressed: () async {
                                      await showDialog<void>(
                                        context: context,
                                        builder: (context) => _ReturnItemDialog(
                                          saleId: saleId,
                                          item: item,
                                        ),
                                      );
                                      ref.invalidate(salesInvoiceDetailProvider(saleId));
                                      ref.invalidate(salesHistoryRowsProvider);
                                    },
                                    child: const Text('Return'),
                                  ),
                          ),
                        ],
                      );
                    }).toList(growable: false),
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

class _CollectPaymentDialog extends ConsumerStatefulWidget {
  const _CollectPaymentDialog({required this.sale});

  final SalesHistoryRowEntity sale;

  @override
  ConsumerState<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends ConsumerState<_CollectPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = FormattingHelpers.decimal(
      widget.sale.remainingBalance,
      fractionDigits: 0,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Collect Payment - ${widget.sale.invoiceNumber}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Outstanding: ${FormattingHelpers.currencyPkr(widget.sale.remainingBalance)}'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PaymentMethod.values
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(PaymentMethod.labels[value]!),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Collecting...' : 'Collect'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final amount = FormattingHelpers.parseLocaleDecimal(_amountController.text);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.collectPayment(
      saleId: widget.sale.saleId,
      amount: amount,
      paymentMethod: _paymentMethod,
      notes: _notesController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    ref.invalidate(salesHistoryRowsProvider);
    ref.invalidate(customerBalanceReportProvider);
    ref.invalidate(cashLedgerRowsProvider);
    AppNotifier.success('Payment collected successfully.');
    Navigator.of(context).pop();
  }
}

class _ReturnItemDialog extends ConsumerStatefulWidget {
  const _ReturnItemDialog({
    required this.saleId,
    required this.item,
  });

  final String saleId;
  final SalesInvoiceItemEntity item;

  @override
  ConsumerState<_ReturnItemDialog> createState() => _ReturnItemDialogState();
}

class _ReturnItemDialogState extends ConsumerState<_ReturnItemDialog> {
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Process Return'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Item: ${widget.item.productName}'),
            Text('Returnable Qty: ${widget.item.returnableQty}'),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyController,
              enabled: !widget.item.hasImei,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Quantity',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Reason (mandatory)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Confirm Return'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final quantity = widget.item.hasImei
        ? 1
        : int.tryParse(_qtyController.text.trim()) ?? 0;
    final result = await service.processReturn(
      saleId: widget.saleId,
      item: widget.item,
      quantity: quantity,
      reason: _reasonController.text,
      notes: _notesController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success('Return processed and stock restored.');
    Navigator.of(context).pop();
  }
}

class _PurchaseDetailDialog extends ConsumerWidget {
  const _PurchaseDetailDialog({required this.purchaseId});

  final String purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseHistoryDetailProvider(purchaseId));
    return AlertDialog(
      title: const Text('Purchase Details'),
      content: SizedBox(
        width: 920,
        height: 500,
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Purchase not found.');
            }
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Supplier: ${detail.purchase.supplierName}'),
                    Text('Date: ${FormattingHelpers.dateYmd(detail.purchase.purchaseDate)}'),
                    Text('Invoice: ${detail.purchase.invoiceNumber ?? '-'}'),
                    Text('Total: ${FormattingHelpers.currencyPkr(detail.purchase.total)}'),
                    Text('Paid: ${FormattingHelpers.currencyPkr(detail.purchase.paidAmount)}'),
                  ],
                ),
                const SizedBox(height: 8),
                if ((detail.notes ?? '').isNotEmpty) ...<Widget>[
                  Text('Notes: ${detail.notes}'),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: AppDataTable(
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('IMEI')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Unit Cost')),
                      DataColumn(label: Text('Line Total')),
                    ],
                    rows: detail.items.map((item) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(item.productName)),
                          DataCell(Text(item.imei ?? '-')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(FormattingHelpers.currencyPkr(item.unitCost))),
                          DataCell(Text(FormattingHelpers.currencyPkr(item.lineTotal))),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Failed to load purchase details.'),
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
    case ReportsTab.salesHistory:
      return 'Sales History';
    case ReportsTab.creditCollection:
      return 'Credit Collection';
    case ReportsTab.purchaseHistory:
      return 'Purchase History';
    case ReportsTab.supplierLedger:
      return 'Supplier Ledger';
    case ReportsTab.cashLedger:
      return 'Cash Flow';
    case ReportsTab.expenses:
      return 'Expenses';
  }
}
