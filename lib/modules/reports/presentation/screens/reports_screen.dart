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
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/ledger_timeline_labels.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/customer_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/supplier_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
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
    ref.invalidate(customerBalanceReportProvider);
    ref.invalidate(purchaseHistoryRowsProvider);
    ref.invalidate(supplierLedgerRowsProvider);
    ref.invalidate(customerLedgerSummaryProvider);
    ref.invalidate(customerLedgerTimelineProvider);
    ref.invalidate(supplierLedgerSummaryProvider);
    ref.invalidate(supplierLedgerTimelineProvider);
    ref.invalidate(cashLedgerRowsProvider);
    ref.invalidate(expensesRowsProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(expenseAnalyticsSummaryProvider);
    ref.invalidate(stockAdjustmentHistoryProvider);
    ref.invalidate(reportRepairAnalyticsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawTab = ref.watch(selectedReportsTabProvider);
    final tab = _normalizeTab(rawTab);
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
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _refreshAll(ref),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
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
                  ),
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
                    onEndDate: (date) => ref
                        .read(reportFilterProvider.notifier)
                        .setEndDate(date),
                    onCustomer: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setCustomerId(value),
                    onProduct: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setProductModelId(value),
                    onStatus: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setStatus(value),
                    onPaymentMethod: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setPaymentMethod(value),
                    onItemType: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setItemType(value),
                    onClear: () =>
                        ref.read(reportFilterProvider.notifier).clearAll(),
                  ),
                  const SizedBox(height: 8),
                ],
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
                            ? () => ref
                                .read(reportFilterProvider.notifier)
                                .nextPage()
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

  ReportsTab _normalizeTab(ReportsTab tab) {
    for (final candidate in ReportsTab.values) {
      if (candidate.name == tab.name) {
        return candidate;
      }
    }
    return ReportsTab.dailySales;
  }

  bool _canGoNextPage({
    required WidgetRef ref,
    required ReportsTab tab,
    required int pageSize,
  }) {
    switch (tab) {
      case ReportsTab.dailySales:
        final dailyRows = ref.watch(dailySalesReportProvider).valueOrNull;
        final detailRows = ref.watch(dateRangeSalesReportProvider).valueOrNull;
        return (dailyRows != null &&
                hasNextReportsPageCandidate(
                  resultsLength: dailyRows.length,
                  pageSize: pageSize,
                )) ||
            (detailRows != null &&
                hasNextReportsPageCandidate(
                  resultsLength: detailRows.length,
                  pageSize: pageSize,
                ));
      case ReportsTab.customerLedger:
      case ReportsTab.profit:
      case ReportsTab.dailyPurchase:
      case ReportsTab.supplierLedger:
      case ReportsTab.cashFlow:
      case ReportsTab.expenses:
      case ReportsTab.repairAnalytics:
        return false;
    }
  }

  bool _usesLegacyFilters(ReportsTab tab) {
    return tab == ReportsTab.dailySales || tab == ReportsTab.profit;
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
    if (tab == ReportsTab.dailySales) {
      return const _DailySalesView();
    }

    if (tab == ReportsTab.profit) {
      return const _ProfitView();
    }

    if (tab == ReportsTab.customerLedger) {
      return const _CustomerBalanceView();
    }

    if (tab == ReportsTab.dailyPurchase) {
      return const _PurchaseHistoryView();
    }

    if (tab == ReportsTab.supplierLedger) {
      return const _SupplierLedgerView();
    }

    if (tab == ReportsTab.cashFlow) {
      return const _CashLedgerView();
    }

    if (tab == ReportsTab.expenses) {
      return const _ExpensesView();
    }

    if (tab == ReportsTab.repairAnalytics) {
      return const _RepairAnalyticsView();
    }

    return const _DailySalesView();
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

  static const double _actionIconSize = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(dateRangeSalesReportProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    if (detailAsync.hasError) {
      return _ReportErrorView(
        message: 'Failed to load sales details report.',
        error: detailAsync.error!,
        onRetry: () => ref.invalidate(dateRangeSalesReportProvider),
      );
    }
    if (detailAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detailRows = detailAsync.value ?? const [];
    final totalInvoices = detailRows.length;
    final totalDays = detailRows
        .map((row) =>
            '${row.saleDate.year}-${row.saleDate.month}-${row.saleDate.day}')
        .toSet()
        .length;
    final totalCustomers = detailRows
        .map((row) => row.customerName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;
    final sumTotal = detailRows.fold<double>(0, (sum, row) => sum + row.total);
    final sumPaid =
        detailRows.fold<double>(0, (sum, row) => sum + row.paidAmount);
    final sumBalance =
        detailRows.fold<double>(0, (sum, row) => sum + row.balance);

    final detailExportRows = detailRows
        .map(
          (row) => <String>[
            row.invoiceNumber,
            FormattingHelpers.dateYmd(row.saleDate),
            row.customerName,
            FormattingHelpers.decimal(row.total),
            FormattingHelpers.decimal(row.paidAmount),
            FormattingHelpers.decimal(row.balance),
            row.paymentMethod ?? '-',
            row.status,
          ],
        )
        .toList();

    final layout = reportTableLayoutFor(context);

    DataRow totalsRow() {
      final style = const TextStyle(fontWeight: FontWeight.bold);
      return DataRow(
        color: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primaryContainer.withAlpha(76),
        ),
        cells: <DataCell>[
          DataCell(Text('TOTAL', style: style)),
          DataCell(Text('Days: $totalDays', style: style)),
          DataCell(Text('Cust: $totalCustomers', style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumTotal), style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumPaid), style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumBalance), style: style)),
          DataCell(Text('Inv: $totalInvoices', style: style)),
          DataCell(Text('-', style: style)),
          DataCell(const SizedBox.shrink()),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Total Sales (page)',
                value: FormattingHelpers.currencyPkr(sumTotal),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Invoices (page)',
                value: totalInvoices.toString(),
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Balance (page)',
                value: FormattingHelpers.currencyPkr(sumBalance),
                color: sumBalance > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: reportSectionTitle('Sales Details')),
                      ReportExportActionWidget(
                        title: 'Daily Sales Details Report',
                        fileBaseName: 'daily_sales_details_report',
                        headers: const <String>[
                          'Invoice',
                          'Date',
                          'Customer',
                          'Total (PKR)',
                          'Paid (PKR)',
                          'Balance (PKR)',
                          'Payment',
                          'Status',
                        ],
                        rows: detailExportRows,
                        csvExportService: csvService,
                        printableReportService: printableService,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AppDataTable(
                      columnSpacing: layout.columnSpacing,
                      dataRowMinHeight: layout.dataRowMinHeight,
                      dataRowMaxHeight: layout.dataRowMaxHeight,
                      showCheckboxColumn: false,
                      columns: <DataColumn>[
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Invoice',
                                width: 130)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(context, 'Date',
                                width: 110)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Customer',
                                width: 220)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Total (PKR)',
                                width: 120)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Paid (PKR)',
                                width: 120)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Balance (PKR)',
                                width: 130)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Payment',
                                width: 100)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Status',
                                width: 100)),
                        DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Actions',
                                width: 132)),
                      ],
                      rows: <DataRow>[
                        ...detailRows.map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(reportStyledTableCell(row.invoiceNumber,
                                  width: 130)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.dateYmd(row.saleDate),
                                  width: 110)),
                              DataCell(reportStyledTableCell(row.customerName,
                                  width: 220)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.total),
                                  width: 120)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.paidAmount),
                                  width: 120)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.balance),
                                  width: 130)),
                              DataCell(reportStyledTableCell(
                                  row.paymentMethod ?? '-',
                                  width: 100)),
                              DataCell(reportStyledTableCell(row.status,
                                  width: 100)),
                              DataCell(
                                SizedBox(
                                  width: 132,
                                  child: Row(
                                    children: <Widget>[
                                      IconButton.filledTonal(
                                        tooltip: 'Open',
                                        onPressed: () => _showInvoiceDialog(
                                          context: context,
                                          saleId: row.saleId,
                                        ),
                                        icon: const Icon(Icons.open_in_new,
                                            size: _actionIconSize),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      if (row.printJobId != null) ...<Widget>[
                                        const SizedBox(width: 6),
                                        IconButton.filledTonal(
                                          tooltip: 'Reprint',
                                          onPressed: () => _reprint(
                                            ref: ref,
                                            jobId: row.printJobId!,
                                          ),
                                          icon: const Icon(Icons.print_outlined,
                                              size: _actionIconSize),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (detailRows.isNotEmpty) totalsRow(),
                      ],
                    ),
                  ),
                ],
              ),
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
    AppNotifier.errorFromAppError(result.asFailure!.error);
  }
}

class _ProfitView extends ConsumerWidget {
  const _ProfitView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(profitReportProvider);
    final rowsAsync = ref.watch(profitReportRowsProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Summary cards ──
        summaryAsync.when(
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
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ReportErrorView(
            message: 'Failed to load profit summary.',
            error: error,
            onRetry: () => ref.invalidate(profitReportProvider),
          ),
        ),

        const SizedBox(height: 12),

        // ── Per-day table ──
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              const headers = <String>[
                'Date',
                'Phones Sold',
                'Accessories Sold',
                'Revenue (PKR)',
                'Cost (PKR)',
                'Profit (PKR)',
                'Margin %',
              ];
              final exportRows = rows
                  .map(
                    (r) => <String>[
                      r.day,
                      r.phonesSold.toString(),
                      r.accessoriesSold.toString(),
                      r.totalRevenue.toStringAsFixed(2),
                      r.totalCost.toStringAsFixed(2),
                      r.totalProfit.toStringAsFixed(2),
                      '${r.marginPercent.toStringAsFixed(1)}%',
                    ],
                  )
                  .toList();
              final layout = reportTableLayoutFor(context);

              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: reportSectionTitle('Profit by Day')),
                          ReportExportActionWidget(
                            title: 'Profit Report',
                            fileBaseName: 'profit_report',
                            headers: headers,
                            rows: exportRows,
                            csvExportService: csvService,
                            printableReportService: printableService,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AppDataTable(
                          columnSpacing: layout.columnSpacing,
                          dataRowMinHeight: layout.dataRowMinHeight,
                          dataRowMaxHeight: layout.dataRowMaxHeight,
                          showCheckboxColumn: false,
                          emptyMessage: 'No profit rows found.',
                          columns: <DataColumn>[
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Date',
                                    width: 110)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Phones Sold',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Accessories Sold',
                                    width: 140)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Revenue (PKR)',
                                    width: 130)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Cost (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Profit (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Margin %',
                                    width: 90)),
                          ],
                          rows: rows.map((r) {
                            final isNegative = r.totalProfit < 0;
                            final colorScheme = Theme.of(context).colorScheme;
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(
                                    reportStyledTableCell(r.day, width: 110)),
                                DataCell(reportStyledTableCell(
                                    r.phonesSold.toString(),
                                    width: 120)),
                                DataCell(reportStyledTableCell(
                                    r.accessoriesSold.toString(),
                                    width: 140)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalRevenue),
                                    width: 130)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalCost),
                                    width: 120)),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: reportStyledStatusCell(
                                        context,
                                        FormattingHelpers.decimal(
                                            r.totalProfit),
                                        isNegative
                                            ? colorScheme.errorContainer
                                            : colorScheme.primaryContainer,
                                        isNegative
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(reportStyledTableCell(
                                    '${r.marginPercent.toStringAsFixed(1)}%',
                                    width: 90)),
                              ],
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ReportErrorView(
              message: 'Failed to load profit breakdown.',
              error: error,
              onRetry: () => ref.invalidate(profitReportRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerOverviewView extends StatelessWidget {
  const _LedgerOverviewView({
    required this.title,
    required this.tableTitle,
    required this.partyHeader,
    required this.openLabel,
    required this.summaries,
    required this.displayName,
    required this.onOpenLedger,
  });

  final String title;
  final String tableTitle;
  final String partyHeader;
  final String openLabel;
  final List<PartySummaryCardEntity> summaries;
  final String Function(String name) displayName;
  final ValueChanged<PartySummaryCardEntity> onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final sorted = List<PartySummaryCardEntity>.of(summaries)
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final totalOutstanding =
        sorted.fold<double>(0, (sum, row) => sum + row.outstanding);
    final withBalance = sorted.where((row) => row.outstanding > 0.009).length;
    final layout = reportTableLayoutFor(context);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Accounts',
                value: sorted.length.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'With balance',
                value: withBalance.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Total outstanding',
                value: FormattingHelpers.currencyPkr(totalOutstanding),
                color: totalOutstanding > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReportTableSection(
            title: tableTitle,
            subtitle: title,
            child: AppDataTable(
              showCheckboxColumn: false,
              emptyMessage: 'No ledger records found.',
              columnSpacing: layout.columnSpacing,
              dataRowMinHeight: layout.dataRowMinHeight,
              dataRowMaxHeight: layout.dataRowMaxHeight,
              columns: <DataColumn>[
                DataColumn(
                  label: reportStyledTableHeaderCell(
                    context,
                    partyHeader,
                    width: 320,
                  ),
                ),
                DataColumn(
                  label: reportStyledTableHeaderCell(
                    context,
                    'Outstanding (PKR)',
                    width: 160,
                  ),
                ),
                DataColumn(
                  label: reportStyledTableHeaderCell(
                    context,
                    'Open',
                    width: 96,
                  ),
                ),
              ],
              rows: sorted.map((summary) {
                void openAccount() => onOpenLedger(summary);
                return DataRow(
                  onSelectChanged: (selected) {
                    if (selected != true) {
                      return;
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      openAccount();
                    });
                  },
                  cells: <DataCell>[
                    DataCell(
                      reportStyledTableCell(
                        displayName(summary.partyName),
                        width: 320,
                      ),
                    ),
                    DataCell(
                      reportStyledTableCell(
                        FormattingHelpers.decimal(summary.outstanding),
                        width: 160,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 96,
                        child: IconButton.filledTonal(
                          tooltip: openLabel,
                          onPressed: openAccount,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerBalanceView extends ConsumerWidget {
  const _CustomerBalanceView();

  void _openLedger(
    BuildContext context,
    WidgetRef ref,
    PartySummaryCardEntity summary,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) {
        return;
      }
      final changed = await CustomerLedgerDetailScreen.open(
        context,
        customerId: summary.partyId,
        summary: summary,
      );
      if (changed == true && context.mounted) {
        ref.invalidate(customerLedgerSummaryProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(customerLedgerSummaryProvider);

    return summaryAsync.when(
      data: (rows) => _LedgerOverviewView(
        title: 'Outstanding customer balances',
        tableTitle: 'Customer Ledger',
        partyHeader: 'Customer',
        openLabel: 'Open customer account',
        summaries: rows,
        displayName: normalizeCustomerLedgerName,
        onOpenLedger: (summary) => _openLedger(context, ref, summary),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => _ReportErrorView(
        message: 'Failed to load customer ledgers.',
        error: error,
        onRetry: () => ref.invalidate(customerLedgerSummaryProvider),
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
                    onChanged: (value) => ref
                        .read(purchaseHistorySupplierQueryProvider.notifier)
                        .state = value,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(purchaseHistoryStartDateProvider) ??
                          DateTime.now(),
                    );
                    ref.read(purchaseHistoryStartDateProvider.notifier).state =
                        picked;
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    ref.watch(purchaseHistoryStartDateProvider) == null
                        ? 'Start Date'
                        : FormattingHelpers.dateYmd(
                            ref.watch(purchaseHistoryStartDateProvider)!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: ref.read(purchaseHistoryEndDateProvider) ??
                          DateTime.now(),
                    );
                    ref.read(purchaseHistoryEndDateProvider.notifier).state =
                        picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    ref.watch(purchaseHistoryEndDateProvider) == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(
                            ref.watch(purchaseHistoryEndDateProvider)!),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              final sumTotal =
                  rows.fold<double>(0, (sum, row) => sum + row.total);
              final sumBalance = rows.fold<double>(
                0,
                (sum, row) => sum + row.remainingBalance,
              );
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Purchases (page)',
                          value: rows.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total (page)',
                          value: FormattingHelpers.currencyPkr(sumTotal),
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Balance (page)',
                          value: FormattingHelpers.currencyPkr(sumBalance),
                          color: sumBalance > 0 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReportTableSection(
                      title: 'Purchase History',
                      child: AppDataTable(
                        columnSpacing:
                            reportTableLayoutFor(context).columnSpacing,
                        dataRowMinHeight:
                            reportTableLayoutFor(context).dataRowMinHeight,
                        dataRowMaxHeight:
                            reportTableLayoutFor(context).dataRowMaxHeight,
                        showCheckboxColumn: false,
                        columns: <DataColumn>[
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Date',
                                  width: 110)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Supplier',
                                  width: 220)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Invoice',
                                  width: 130)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Total (PKR)',
                                  width: 120)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Paid (PKR)',
                                  width: 120)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Balance (PKR)',
                                  width: 130)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Actions',
                                  width: 90)),
                        ],
                        rows: rows.map((row) {
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.dateYmd(row.purchaseDate),
                                  width: 110)),
                              DataCell(reportStyledTableCell(row.supplierName,
                                  width: 220)),
                              DataCell(reportStyledTableCell(
                                  row.invoiceNumber ?? '-',
                                  width: 130)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.total),
                                  width: 120)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.paidAmount),
                                  width: 120)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(
                                      row.remainingBalance),
                                  width: 130)),
                              DataCell(
                                IconButton.filledTonal(
                                  tooltip: 'Open',
                                  onPressed: () async {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (context) =>
                                          _PurchaseDetailDialog(
                                        purchaseId: row.purchaseId,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                ],
              );
            },
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

  void _openLedger(
    BuildContext context,
    WidgetRef ref,
    PartySummaryCardEntity summary,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) {
        return;
      }
      final changed = await SupplierLedgerDetailScreen.open(
        context,
        supplierId: summary.partyId,
        summary: summary,
      );
      if (changed == true && context.mounted) {
        ref.invalidate(supplierLedgerSummaryProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(supplierLedgerSummaryProvider);

    return summaryAsync.when(
      data: (rows) => _LedgerOverviewView(
        title: 'Outstanding supplier balances',
        tableTitle: 'Supplier Ledger',
        partyHeader: 'Supplier',
        openLabel: 'Open supplier account',
        summaries: rows,
        displayName: normalizeSupplierLedgerName,
        onOpenLedger: (summary) => _openLedger(context, ref, summary),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => _ReportErrorView(
        message: 'Failed to load supplier ledgers.',
        error: error,
        onRetry: () => ref.invalidate(supplierLedgerSummaryProvider),
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
                      initialDate: ref.read(cashLedgerStartDateProvider) ??
                          DateTime.now(),
                    );
                    ref.read(cashLedgerStartDateProvider.notifier).state =
                        picked;
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
                          ref.read(cashLedgerEndDateProvider) ?? DateTime.now(),
                    );
                    ref.read(cashLedgerEndDateProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    endDate == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(endDate),
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
            data: (rows) {
              final netTotal =
                  rows.fold<double>(0, (sum, row) => sum + row.netCash);
              final cashIn = rows.fold<double>(
                0,
                (sum, row) => sum + row.totalCashIn,
              );
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Cash in (page)',
                          value: FormattingHelpers.currencyPkr(cashIn),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Net cash (page)',
                          value: FormattingHelpers.currencyPkr(netTotal),
                          color: netTotal >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReportTableSection(
                      title: 'Cash Flow',
                      subtitle:
                          'Cash movement only (sales, collections, refunds, purchases paid, expenses). Not physical drawer cash.',
                      child: AppDataTable(
                        emptyMessage:
                            'No cash flow rows in selected date range.',
                        columnSpacing:
                            reportTableLayoutFor(context).columnSpacing,
                        dataRowMinHeight:
                            reportTableLayoutFor(context).dataRowMinHeight,
                        dataRowMaxHeight:
                            reportTableLayoutFor(context).dataRowMaxHeight,
                        showCheckboxColumn: false,
                        columns: <DataColumn>[
                          DataColumn(
                              label: reportStyledTableHeaderCell(context, 'Day',
                                  width: 105)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Cash Sales In (PKR)',
                                  width: 140)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Collections In (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Total Cash In (PKR)',
                                  width: 140)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Cash Refunds Out (PKR)',
                                  width: 160)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Purchases Paid Out (PKR)',
                                  width: 175)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Expenses Out (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Total Cash Out (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: reportStyledTableHeaderCell(
                                  context, 'Net Cash (PKR)',
                                  width: 130)),
                        ],
                        rows: rows.map((row) {
                          final colorScheme = Theme.of(context).colorScheme;
                          final isNegative = row.netCash < 0;
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(
                                  reportStyledTableCell(row.day, width: 105)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.cashSalesIn),
                                  width: 140)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(
                                      row.cashCollectionsIn),
                                  width: 145)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.totalCashIn),
                                  width: 140)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.cashRefundsOut),
                                  width: 160)),
                              DataCell(
                                reportStyledTableCell(
                                    FormattingHelpers.decimal(
                                        row.purchasePaymentsOut),
                                    width: 175),
                              ),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.expensesOut),
                                  width: 145)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.totalCashOut),
                                  width: 145)),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: reportStyledStatusCell(
                                      context,
                                      FormattingHelpers.decimal(row.netCash),
                                      isNegative
                                          ? colorScheme.errorContainer
                                          : colorScheme.primaryContainer,
                                      isNegative
                                          ? colorScheme.onErrorContainer
                                          : colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                ],
              );
            },
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

// ─────────────────────────────────────────────────────────────
// Expenses View
// ─────────────────────────────────────────────────────────────
const List<String> _pakistaniExpenseCategories = <String>[
  'Shop Rent',
  'Electricity Bill',
  'Internet Bill',
  'Mobile Load',
  'Employee Salary',
  'Tea / Refreshments',
  'Cleaning Expense',
  'Stationery',
  'Transport / Fuel',
  'Courier Charges',
  'Repair Tools',
  'Mobile Parts Purchase',
  'Accessory Purchase',
  'Shop Maintenance',
  'Printer Paper',
  'Thermal Roll',
  'Software Maintenance',
  'Marketing / Advertisement',
  'Tax / PTA Fee',
  'Security / CCTV',
  'Packaging Material',
  'Customer Compensation',
  'Miscellaneous',
  'Other',
];

class _ExpensesView extends ConsumerStatefulWidget {
  const _ExpensesView();

  @override
  ConsumerState<_ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<_ExpensesView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(expensesSearchRemarksProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(expensesRowsProvider);
    final summaryAsync = ref.watch(expenseAnalyticsSummaryProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final startDate = ref.watch(expensesStartDateProvider);
    final endDate = ref.watch(expensesEndDateProvider);
    final selectedCategory = ref.watch(expensesCategoryProvider);
    final selectedPaymentMethod = ref.watch(expensesPaymentMethodProvider);

    if (rowsAsync.hasError) {
      return _ReportErrorView(
        message: 'Failed to load expenses.',
        error: rowsAsync.error!,
        onRetry: _invalidateExpenseProviders,
      );
    }

    final existingCategories = categoriesAsync.valueOrNull ?? const <String>[];
    final categoryOptions = _mergedExpenseCategories(existingCategories);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            summaryAsync.when(
              data: (summary) => _ExpenseSummaryCards(
                summary: summary,
                isCompact: isCompact,
              ),
              loading: () => const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ExpenseInlineError(
                message: 'Failed to load expense summary.',
                onRetry: _invalidateExpenseProviders,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => _openExpenseDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDate: startDate ?? DateTime.now(),
                        );
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesStartDateProvider.notifier).state =
                            picked;
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
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
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDate: endDate ?? DateTime.now(),
                        );
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesEndDateProvider.notifier).state =
                            picked;
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        endDate == null
                            ? 'End Date'
                            : FormattingHelpers.dateYmd(endDate),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            selectedCategory.isEmpty ? null : selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Category',
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All Categories'),
                          ),
                          ...categoryOptions.map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          ref.read(expensesCategoryProvider.notifier).state =
                              value ?? '';
                        },
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPaymentMethod.isEmpty
                            ? null
                            : selectedPaymentMethod,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Payment',
                          isDense: true,
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text('All Payments'),
                          ),
                          DropdownMenuItem<String>(
                            value: PaymentMethod.cash,
                            child: Text('Cash'),
                          ),
                          DropdownMenuItem<String>(
                            value: PaymentMethod.card,
                            child: Text('Card'),
                          ),
                          DropdownMenuItem<String>(
                            value: PaymentMethod.bank,
                            child: Text('Bank Transfer'),
                          ),
                        ],
                        onChanged: (value) {
                          ref
                              .read(expensesPaymentMethodProvider.notifier)
                              .state = value ?? '';
                        },
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? constraints.maxWidth : 260,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(expensesSearchRemarksProvider.notifier)
                            .state = value,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Search remarks',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(expensesSearchRemarksProvider
                                            .notifier)
                                        .state = '';
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: rowsAsync.when(
                data: (rows) => _ExpensesTableSection(
                  rows: rows,
                  isCompact: isCompact,
                  onAdd: () => _openExpenseDialog(),
                  onEdit: (expense) => _openExpenseDialog(expense: expense),
                  onDelete: _confirmDeleteExpense,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ReportErrorView(
                  message: 'Failed to load expenses.',
                  error: error,
                  onRetry: _invalidateExpenseProviders,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearFilters() {
    ref.read(expensesStartDateProvider.notifier).state = null;
    ref.read(expensesEndDateProvider.notifier).state = null;
    ref.read(expensesCategoryProvider.notifier).state = '';
    ref.read(expensesPaymentMethodProvider.notifier).state = '';
    ref.read(expensesSearchRemarksProvider.notifier).state = '';
    _searchController.clear();
    setState(() {});
  }

  Future<void> _openExpenseDialog({ExpenseEntity? expense}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ExpenseFormDialog(expense: expense),
    );
    if (changed == true && mounted) {
      _invalidateExpenseProviders();
    }
  }

  Future<void> _confirmDeleteExpense(ExpenseEntity expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: 'Delete Expense',
        message:
            'Delete ${expense.displayCategory} expense of ${FormattingHelpers.currencyPkr(expense.amount)}? This will remove it from cash movement reports.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true) {
      return;
    }
    final repository = await ref.read(expenseRepositoryProvider.future);
    final result = await repository.deleteExpense(expense.id);
    if (!mounted) {
      return;
    }
    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success('Expense deleted.');
    _invalidateExpenseProviders();
  }

  void _invalidateExpenseProviders() {
    ref.invalidate(expensesRowsProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(expenseAnalyticsSummaryProvider);
    ref.invalidate(cashLedgerRowsProvider);
  }
}

class _ExpenseSummaryCards extends StatelessWidget {
  const _ExpenseSummaryCards({
    required this.summary,
    required this.isCompact,
  });

  final ExpenseAnalyticsSummary summary;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      ReportSummaryCardWidget(
        label: "Today's Expense",
        value: FormattingHelpers.currencyPkr(summary.todayTotal),
        color: Colors.red.shade700,
      ),
      ReportSummaryCardWidget(
        label: 'Monthly Expense',
        value: FormattingHelpers.currencyPkr(summary.thisMonthTotal),
        color: Colors.orange.shade800,
      ),
      ReportSummaryCardWidget(
        label: 'Total Expense',
        value: FormattingHelpers.currencyPkr(summary.allTimeTotal),
        color: Colors.indigo,
      ),
      ReportSummaryCardWidget(
        label: 'Highest Expense Category',
        value: summary.highestCategory ?? '-',
        color: Colors.teal.shade700,
      ),
    ];

    if (isCompact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(width: double.infinity, child: card),
              ),
            )
            .toList(growable: false),
      );
    }

    return Row(
      children: <Widget>[
        for (var index = 0; index < cards.length; index++) ...<Widget>[
          Expanded(child: cards[index]),
          if (index != cards.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ExpenseFormDialog extends ConsumerStatefulWidget {
  const _ExpenseFormDialog({this.expense});

  final ExpenseEntity? expense;

  @override
  ConsumerState<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<_ExpenseFormDialog> {
  late final TextEditingController _customCategoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _remarksController;
  late DateTime _expenseDate;
  late String _category;
  late String _paymentMethod;
  bool _isSubmitting = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _expenseDate = expense?.expenseDate.toLocal() ?? DateTime.now();
    _category = _pakistaniExpenseCategories.contains(expense?.category)
        ? expense!.category
        : expense == null
            ? _pakistaniExpenseCategories.first
            : 'Other';
    _paymentMethod = PaymentMethod.normalizeNullable(expense?.paymentMethod) ??
        PaymentMethod.cash;
    _customCategoryController = TextEditingController(
      text: expense?.customCategory ??
          (!_pakistaniExpenseCategories.contains(expense?.category)
              ? expense?.category ?? ''
              : ''),
    );
    _amountController = TextEditingController(
      text: expense == null ? '' : FormattingHelpers.decimal(expense.amount),
    );
    _remarksController = TextEditingController(text: expense?.remarks ?? '');
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Expense Category',
                  isDense: true,
                ),
                items: _pakistaniExpenseCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                          () => _category =
                              value ?? _pakistaniExpenseCategories.first,
                        ),
              ),
              if (_category == 'Other') ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: _customCategoryController,
                  enabled: !_isSubmitting,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Custom Category',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                enabled: !_isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Payment Method',
                  isDense: true,
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: PaymentMethod.cash,
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentMethod.card,
                    child: Text('Card'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentMethod.bank,
                    child: Text('Bank Transfer'),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                          () => _paymentMethod = value ?? PaymentMethod.cash,
                        ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _remarksController,
                enabled: !_isSubmitting,
                maxLines: 4,
                maxLength: 300,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(300),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Remarks (optional)',
                  isDense: true,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Save Expense'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final category = _category.trim();
    final customCategory = _customCategoryController.text.trim();
    if (category.isEmpty || (category == 'Other' && customCategory.isEmpty)) {
      AppNotifier.error('Category is required.');
      return;
    }
    final amount =
        FormattingHelpers.tryParseGroupedDecimalStrict(_amountController.text);
    if (amount == null || amount.isNaN) {
      AppNotifier.error('Please enter a valid amount.');
      return;
    }
    if (amount <= 0) {
      AppNotifier.error('Amount must be greater than zero.');
      return;
    }
    if (!amount.isFinite) {
      AppNotifier.error('Please enter a valid amount.');
      return;
    }
    final paymentMethod = PaymentMethod.normalizeNullable(_paymentMethod);
    if (paymentMethod == null || paymentMethod == PaymentMethod.credit) {
      AppNotifier.error('Payment method must be cash, card, or bank.');
      return;
    }

    setState(() => _isSubmitting = true);
    final repository = await ref.read(expenseRepositoryProvider.future);
    final now = DateTimeHelpers.nowUtc();
    final existing = widget.expense;
    final payload = ExpenseEntity(
      id: existing?.id ?? IdHelpers.newId(prefix: 'exp'),
      expenseDate: DateTime.utc(
        _expenseDate.year,
        _expenseDate.month,
        _expenseDate.day,
      ),
      category: category,
      customCategory: category == 'Other' ? customCategory : null,
      amount: amount,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      paymentMethod: paymentMethod,
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
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success(_isEdit ? 'Expense updated.' : 'Expense added.');
    Navigator.of(context).pop(true);
  }
}

class _ExpenseInlineError extends StatelessWidget {
  const _ExpenseInlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(message)),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesTableSection extends StatelessWidget {
  const _ExpensesTableSection({
    required this.rows,
    required this.isCompact,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final bool isCompact;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('No expenses found'),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
            ],
          ),
        ),
      );
    }

    final total = rows.fold<double>(0, (sum, expense) => sum + expense.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: reportSectionTitle('Expense Records')),
                Text(
                  '${rows.length} rows | ${FormattingHelpers.currencyPkr(total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: isCompact
                  ? _ExpenseCardList(
                      rows: rows,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    )
                  : _ExpenseDesktopTable(
                      rows: rows,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDesktopTable extends StatelessWidget {
  const _ExpenseDesktopTable({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final layout = reportTableLayoutFor(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1040,
        child: AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 88,
          showCheckboxColumn: false,
          emptyMessage: 'No expenses found',
          columns: <DataColumn>[
            DataColumn(
              label: reportStyledTableHeaderCell(context, 'Date', width: 110),
            ),
            DataColumn(
              label:
                  reportStyledTableHeaderCell(context, 'Category', width: 170),
            ),
            DataColumn(
              label:
                  reportStyledTableHeaderCell(context, 'Remarks', width: 360),
            ),
            DataColumn(
              label: reportStyledTableHeaderCell(
                context,
                'Payment Method',
                width: 130,
              ),
            ),
            DataColumn(
              numeric: true,
              label: reportStyledTableHeaderCell(context, 'Amount', width: 120),
            ),
            DataColumn(
              label:
                  reportStyledTableHeaderCell(context, 'Actions', width: 110),
            ),
          ],
          rows: rows
              .map(
                (expense) => DataRow(
                  cells: <DataCell>[
                    DataCell(reportStyledTableCell(
                      FormattingHelpers.dateYmd(expense.expenseDate),
                      width: 110,
                    )),
                    DataCell(reportStyledTableCell(
                      expense.displayCategory,
                      width: 170,
                    )),
                    DataCell(
                      SizedBox(
                        width: 360,
                        child: Text(
                          expense.remarks?.trim().isNotEmpty == true
                              ? expense.remarks!.trim()
                              : '-',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ),
                    ),
                    DataCell(reportStyledTableCell(
                      _paymentMethodLabel(expense.paymentMethod),
                      width: 130,
                    )),
                    DataCell(reportStyledTableCell(
                      FormattingHelpers.currencyPkr(expense.amount),
                      width: 120,
                      textAlign: TextAlign.right,
                    )),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(expense),
                              icon: const Icon(Icons.edit, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => onDelete(expense),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ExpenseCardList extends StatelessWidget {
  const _ExpenseCardList({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final expense = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        expense.displayCategory,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      FormattingHelpers.currencyPkr(expense.amount),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${FormattingHelpers.dateYmd(expense.expenseDate)} | ${_paymentMethodLabel(expense.paymentMethod)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (expense.remarks?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(expense.remarks!.trim()),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEdit(expense),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => onDelete(expense),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<String> _mergedExpenseCategories(List<String> existingCategories) {
  final seen = <String>{};
  final output = <String>[];
  for (final category in <String>[
    ..._pakistaniExpenseCategories,
    ...existingCategories,
  ]) {
    final normalized = category.trim();
    if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) {
      continue;
    }
    output.add(normalized);
  }
  return output;
}

String _paymentMethodLabel(String? paymentMethod) {
  final normalized = PaymentMethod.normalizeNullable(paymentMethod);
  return normalized == null
      ? '-'
      : PaymentMethod.labels[normalized] ?? normalized;
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
                    columnSpacing: reportTableLayoutFor(context).columnSpacing,
                    dataRowMinHeight:
                        reportTableLayoutFor(context).dataRowMinHeight,
                    dataRowMaxHeight:
                        reportTableLayoutFor(context).dataRowMaxHeight,
                    showCheckboxColumn: false,
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
                          DataCell(Text(
                              FormattingHelpers.currencyPkr(item.unitPrice))),
                          DataCell(Text(
                              FormattingHelpers.currencyPkr(item.lineTotal))),
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
                                      ref.invalidate(
                                          salesInvoiceDetailProvider(saleId));
                                      ref.invalidate(
                                          dateRangeSalesReportProvider);
                                      ref.invalidate(dailySalesReportProvider);
                                      ref.invalidate(profitReportProvider);
                                      ref.invalidate(profitReportRowsProvider);
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
  ConsumerState<_CollectPaymentDialog> createState() =>
      _CollectPaymentDialogState();
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
            Text(
                'Outstanding: ${FormattingHelpers.currencyPkr(widget.sale.remainingBalance)}'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PaymentMethod.values
                  .where((value) => value != PaymentMethod.credit)
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
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    ref.invalidate(dateRangeSalesReportProvider);
    ref.invalidate(customerBalanceReportProvider);
    ref.invalidate(customerLedgerSummaryProvider);
    ref.invalidate(customerLedgerTimelineProvider);
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
    final quantity =
        widget.item.hasImei ? 1 : int.tryParse(_qtyController.text.trim()) ?? 0;
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
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success('Return processed and stock restored.');
    ref.invalidate(dailySalesReportProvider);
    ref.invalidate(dateRangeSalesReportProvider);
    ref.invalidate(profitReportProvider);
    ref.invalidate(profitReportRowsProvider);
    ref.invalidate(customerLedgerSummaryProvider);
    ref.invalidate(customerLedgerTimelineProvider);
    ref.invalidate(cashLedgerRowsProvider);
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
                    Text(
                        'Date: ${FormattingHelpers.dateYmd(detail.purchase.purchaseDate)}'),
                    Text('Invoice: ${detail.purchase.invoiceNumber ?? '-'}'),
                    Text(
                        'Total: ${FormattingHelpers.currencyPkr(detail.purchase.total)}'),
                    Text(
                        'Paid: ${FormattingHelpers.currencyPkr(detail.purchase.paidAmount)}'),
                  ],
                ),
                const SizedBox(height: 8),
                if ((detail.notes ?? '').isNotEmpty) ...<Widget>[
                  Text('Notes: ${detail.notes}'),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: AppDataTable(
                    columnSpacing: reportTableLayoutFor(context).columnSpacing,
                    dataRowMinHeight:
                        reportTableLayoutFor(context).dataRowMinHeight,
                    dataRowMaxHeight:
                        reportTableLayoutFor(context).dataRowMaxHeight,
                    showCheckboxColumn: false,
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
                          DataCell(Text(
                              FormattingHelpers.currencyPkr(item.unitCost))),
                          DataCell(Text(
                              FormattingHelpers.currencyPkr(item.lineTotal))),
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

class _RepairAnalyticsView extends ConsumerWidget {
  const _RepairAnalyticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDate = ref.watch(reportRepairAnalyticsStartDateProvider);
    final endDate = ref.watch(reportRepairAnalyticsEndDateProvider);
    final analyticsAsync = ref.watch(reportRepairAnalyticsProvider);

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
                  onPressed: () {
                    final now = DateTime.now();
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = DateTime(now.year, now.month, 1);
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = DateTime(now.year, now.month + 1, 0);
                  },
                  icon: const Icon(Icons.calendar_view_month, size: 16),
                  label: const Text('This Month'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final now = DateTime.now();
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = DateTime(now.year, 1, 1);
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = DateTime(now.year, 12, 31);
                  },
                  child: const Text('This Year'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: startDate ?? DateTime.now(),
                    );
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = picked;
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
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
                      initialDate: endDate ?? DateTime.now(),
                    );
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = picked;
                  },
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    endDate == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(endDate),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = null;
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = null;
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('All Time'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: analyticsAsync.when(
            data: (analytics) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Repairs',
                          value: analytics.totalRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Delivered',
                          value: analytics.deliveredRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Pending',
                          value: analytics.pendingRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Earnings',
                          value: FormattingHelpers.currencyPkr(
                            analytics.totalEarnings,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Expenses',
                          value: FormattingHelpers.currencyPkr(
                            analytics.totalExpenses,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _AnalyticsTable(
                            title: 'Issue Analysis',
                            minHeight: 220,
                            columns: <DataColumn>[
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                  context,
                                  'Issue',
                                  width: 200,
                                ),
                              ),
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                  context,
                                  'Count',
                                  width: 80,
                                ),
                              ),
                            ],
                            rows: analytics.issueGroups
                                .map(
                                  (g) => DataRow(
                                    cells: <DataCell>[
                                      DataCell(
                                        reportStyledTableCell(
                                          g.issue,
                                          width: 200,
                                        ),
                                      ),
                                      DataCell(
                                        reportStyledTableCell(
                                          g.count.toString(),
                                          width: 80,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            emptyMessage: 'No issues recorded.',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AnalyticsTable(
                            title: 'Top Phone Models',
                            minHeight: 220,
                            columns: <DataColumn>[
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                  context,
                                  'Model',
                                  width: 200,
                                ),
                              ),
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                  context,
                                  'Repairs',
                                  width: 80,
                                ),
                              ),
                            ],
                            rows: analytics.topModels
                                .map(
                                  (m) => DataRow(
                                    cells: <DataCell>[
                                      DataCell(
                                        reportStyledTableCell(
                                          m.model,
                                          width: 200,
                                        ),
                                      ),
                                      DataCell(
                                        reportStyledTableCell(
                                          m.count.toString(),
                                          width: 80,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            emptyMessage: 'No data.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AnalyticsTable(
                    title: 'Monthly Trend',
                    minHeight: 180,
                    columns: <DataColumn>[
                      DataColumn(
                        label: reportStyledTableHeaderCell(
                          context,
                          'Month',
                          width: 120,
                        ),
                      ),
                      DataColumn(
                        label: reportStyledTableHeaderCell(
                          context,
                          'Repairs',
                          width: 90,
                        ),
                      ),
                      DataColumn(
                        label: reportStyledTableHeaderCell(
                          context,
                          'Earnings (PKR)',
                          width: 140,
                        ),
                      ),
                    ],
                    rows: analytics.monthlyTrend
                        .map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(
                                reportStyledTableCell(row.month, width: 120),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  row.repairs.toString(),
                                  width: 90,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.currencyPkr(row.earnings),
                                  width: 140,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(growable: false),
                    emptyMessage: 'No monthly data.',
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Failed to load repair analytics.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(reportRepairAnalyticsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsTable extends StatelessWidget {
  const _AnalyticsTable({
    required this.title,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    this.minHeight = 200,
  });

  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final layout = reportTableLayoutFor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            reportSectionTitle(title),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: AppDataTable(
                columnSpacing: layout.columnSpacing,
                dataRowMinHeight: layout.dataRowMinHeight,
                dataRowMaxHeight: layout.dataRowMaxHeight,
                showCheckboxColumn: false,
                columns: columns,
                rows: rows,
                emptyMessage: emptyMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _tabLabel(ReportsTab tab) {
  switch (tab) {
    case ReportsTab.dailySales:
      return 'Daily Sales';
    case ReportsTab.dailyPurchase:
      return 'Daily Purchase';
    case ReportsTab.profit:
      return 'Profit';
    case ReportsTab.cashFlow:
      return 'Cash Flow';
    case ReportsTab.expenses:
      return 'Expenses';
    case ReportsTab.repairAnalytics:
      return 'Repair Analytics';
    case ReportsTab.customerLedger:
      return 'Customer Ledger';
    case ReportsTab.supplierLedger:
      return 'Supplier Ledger';
  }
}
