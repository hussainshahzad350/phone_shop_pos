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
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/widgets/ledger_widgets.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
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
// ─── Report Table Styling Utilities ───

Widget _styledTableHeaderCell(BuildContext context, String label,
    {double? width}) {
  final theme = Theme.of(context);
  return SizedBox(
    width: width,
    child: Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}

Widget _styledTableCell(String value,
    {double? width, TextAlign textAlign = TextAlign.left}) {
  return SizedBox(
    width: width,
    child: Text(
      value,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _styledStatusCell(
    BuildContext context, String label, Color bgColor, Color fgColor) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: fgColor,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _indexCell(int index, {double width = 56}) {
  return SizedBox(
    width: width,
    child: Text(
      (index + 1).toString(),
      textAlign: TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
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
    return tab == ReportsTab.dailySales ||
        tab == ReportsTab.profit;
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

    final layout = _reportTableLayoutFor(context);

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
                      const Expanded(
                        child: Text(
                          'Sales Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
                            label: _styledTableHeaderCell(context, 'Invoice',
                                width: 130)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Date',
                                width: 110)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Customer',
                                width: 220)),
                        DataColumn(
                            label: _styledTableHeaderCell(
                                context, 'Total (PKR)',
                                width: 120)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Paid (PKR)',
                                width: 120)),
                        DataColumn(
                            label: _styledTableHeaderCell(
                                context, 'Balance (PKR)',
                                width: 130)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Payment',
                                width: 100)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Status',
                                width: 100)),
                        DataColumn(
                            label: _styledTableHeaderCell(context, 'Actions',
                                width: 132)),
                      ],
                      rows: <DataRow>[
                        ...detailRows.map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(_styledTableCell(row.invoiceNumber,
                                  width: 130)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.dateYmd(row.saleDate),
                                  width: 110)),
                              DataCell(_styledTableCell(row.customerName,
                                  width: 220)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.total),
                                  width: 120)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.paidAmount),
                                  width: 120)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.balance),
                                  width: 130)),
                              DataCell(_styledTableCell(
                                  row.paymentMethod ?? '-',
                                  width: 100)),
                              DataCell(
                                  _styledTableCell(row.status, width: 100)),
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
    AppNotifier.error(result.asFailure!.error.message);
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
              final layout = _reportTableLayoutFor(context);

              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: ReportExportActionWidget(
                          title: 'Profit Report',
                          fileBaseName: 'profit_report',
                          headers: headers,
                          rows: exportRows,
                          csvExportService: csvService,
                          printableReportService: printableService,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: AppDataTable(
                          columnSpacing: layout.columnSpacing,
                          dataRowMinHeight: layout.dataRowMinHeight,
                          dataRowMaxHeight: layout.dataRowMaxHeight,
                          showCheckboxColumn: false,
                          emptyMessage: 'No profit rows found.',
                          columns: <DataColumn>[
                            DataColumn(
                                label: _styledTableHeaderCell(context, 'Date',
                                    width: 110)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Phones Sold',
                                    width: 120)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Accessories Sold',
                                    width: 140)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Revenue (PKR)',
                                    width: 130)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Cost (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Profit (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: _styledTableHeaderCell(
                                    context, 'Margin %',
                                    width: 90)),
                          ],
                          rows: rows.map((r) {
                            final isNegative = r.totalProfit < 0;
                            final colorScheme = Theme.of(context).colorScheme;
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(_styledTableCell(r.day, width: 110)),
                                DataCell(_styledTableCell(
                                    r.phonesSold.toString(),
                                    width: 120)),
                                DataCell(_styledTableCell(
                                    r.accessoriesSold.toString(),
                                    width: 140)),
                                DataCell(_styledTableCell(
                                    FormattingHelpers.decimal(r.totalRevenue),
                                    width: 130)),
                                DataCell(_styledTableCell(
                                    FormattingHelpers.decimal(r.totalCost),
                                    width: 120)),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _styledStatusCell(
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
                                DataCell(_styledTableCell(
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

class _CustomerBalanceView extends ConsumerWidget {
  const _CustomerBalanceView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(customerLedgerSummaryProvider);
    final timelineAsync = ref.watch(customerLedgerTimelineProvider);
    final selectedCustomerId = ref.watch(customerLedgerTimelineCustomerIdProvider);
    final selectedType = ref.watch(customerLedgerTimelineTypeProvider);
    final outstandingOnly = ref.watch(customerLedgerTimelineOutstandingOnlyProvider);
    final paymentHistory = ref.watch(customerLedgerTimelinePaymentHistoryProvider);

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
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    value: selectedCustomerId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Customer',
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Customers'),
                      ),
                      ...summaryAsync.valueOrNull
                              ?.map(
                                (summary) => DropdownMenuItem<String?>(
                                  value: summary.partyId,
                                  child: Text(summary.partyName),
                                ),
                              )
                              .toList(growable: false) ??
                          const <DropdownMenuItem<String?>>[],
                    ],
                    onChanged: (value) => ref
                        .read(customerLedgerTimelineCustomerIdProvider.notifier)
                        .state = value,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Ledger Type',
                    ),
                    items: const <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Types'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'sale',
                        child: Text('Sale'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'sale_payment',
                        child: Text('Sale Payment'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'sale_return',
                        child: Text('Sale Return'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'repair_due',
                        child: Text('Repair Due'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'repair_payment',
                        child: Text('Repair Payment'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'manual_settlement',
                        child: Text('Manual Settlement'),
                      ),
                    ],
                    onChanged: (value) => ref
                        .read(customerLedgerTimelineTypeProvider.notifier)
                        .state = value,
                  ),
                ),
                FilterChip(
                  label: const Text('Outstanding only'),
                  selected: outstandingOnly,
                  onSelected: (value) => ref
                      .read(customerLedgerTimelineOutstandingOnlyProvider.notifier)
                      .state = value,
                ),
                FilterChip(
                  label: const Text('Payment history'),
                  selected: paymentHistory,
                  onSelected: (value) => ref
                      .read(customerLedgerTimelinePaymentHistoryProvider.notifier)
                      .state = value,
                ),
                FilledButton.icon(
                  onPressed: selectedCustomerId == null
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _ReceiveCustomerCreditDialog(customerId: selectedCustomerId),
                          );
                          ref.invalidate(customerLedgerSummaryProvider);
                          ref.invalidate(customerLedgerTimelineProvider);
                          ref.invalidate(cashLedgerRowsProvider);
                        },
                  icon: const Icon(Icons.south_west, size: 18),
                  label: const Text('Receive Credit'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: timelineAsync.when(
            data: (timelineRows) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: <Widget>[
                    if ((summaryAsync.valueOrNull ??
                            const <PartySummaryCardEntity>[])
                        .isNotEmpty) ...<Widget>[
                      LedgerSummaryCards(
                        summary: (summaryAsync.valueOrNull ??
                                const <PartySummaryCardEntity>[])
                            .firstWhere(
                          (summary) => selectedCustomerId == null || summary.partyId == selectedCustomerId,
                          orElse: () => (summaryAsync.valueOrNull ??
                              const <PartySummaryCardEntity>[]).first,
                        ),
                        balanceLabel: 'Net',
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(child: LedgerTimelineTable(rows: timelineRows)),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load customer ledger timeline.',
              error: error,
              onRetry: () {
                ref.invalidate(customerLedgerSummaryProvider);
                ref.invalidate(customerLedgerTimelineProvider);
              },
            ),
          ),
        ),
      ],
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
            data: (rows) => Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: AppDataTable(
                  columnSpacing: _reportTableLayoutFor(context).columnSpacing,
                  dataRowMinHeight:
                      _reportTableLayoutFor(context).dataRowMinHeight,
                  dataRowMaxHeight:
                      _reportTableLayoutFor(context).dataRowMaxHeight,
                  showCheckboxColumn: false,
                  columns: <DataColumn>[
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Date',
                            width: 110)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Supplier',
                            width: 220)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Invoice',
                            width: 130)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Total (PKR)',
                            width: 120)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Paid (PKR)',
                            width: 120)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Balance (PKR)',
                            width: 130)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Actions',
                            width: 90)),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(_styledTableCell(
                            FormattingHelpers.dateYmd(row.purchaseDate),
                            width: 110)),
                        DataCell(
                            _styledTableCell(row.supplierName, width: 220)),
                        DataCell(_styledTableCell(row.invoiceNumber ?? '-',
                            width: 130)),
                        DataCell(_styledTableCell(
                            FormattingHelpers.decimal(row.total),
                            width: 120)),
                        DataCell(_styledTableCell(
                            FormattingHelpers.decimal(row.paidAmount),
                            width: 120)),
                        DataCell(_styledTableCell(
                            FormattingHelpers.decimal(row.remainingBalance),
                            width: 130)),
                        DataCell(
                          IconButton.filledTonal(
                            tooltip: 'Open',
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (context) => _PurchaseDetailDialog(
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
    final summaryAsync = ref.watch(supplierLedgerSummaryProvider);
    final timelineAsync = ref.watch(supplierLedgerTimelineProvider);
    final selectedSupplierId = ref.watch(supplierLedgerTimelineSupplierIdProvider);
    final outstandingOnly = ref.watch(supplierLedgerTimelineOutstandingOnlyProvider);
    final paymentHistory = ref.watch(supplierLedgerTimelinePaymentHistoryProvider);

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
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    value: selectedSupplierId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Supplier',
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Suppliers'),
                      ),
                      ...summaryAsync.valueOrNull
                              ?.map(
                                (summary) => DropdownMenuItem<String?>(
                                  value: summary.partyId,
                                  child: Text(summary.partyName),
                                ),
                              )
                              .toList(growable: false) ??
                          const <DropdownMenuItem<String?>>[],
                    ],
                    onChanged: (value) => ref
                        .read(supplierLedgerTimelineSupplierIdProvider.notifier)
                        .state = value,
                  ),
                ),
                FilterChip(
                  label: const Text('Outstanding only'),
                  selected: outstandingOnly,
                  onSelected: (value) => ref
                      .read(supplierLedgerTimelineOutstandingOnlyProvider.notifier)
                      .state = value,
                ),
                FilterChip(
                  label: const Text('Payment history'),
                  selected: paymentHistory,
                  onSelected: (value) => ref
                      .read(supplierLedgerTimelinePaymentHistoryProvider.notifier)
                      .state = value,
                ),
                FilledButton.icon(
                  onPressed: selectedSupplierId == null
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _PaySupplierCreditDialog(supplierId: selectedSupplierId),
                          );
                          ref.invalidate(supplierLedgerSummaryProvider);
                          ref.invalidate(supplierLedgerTimelineProvider);
                          ref.invalidate(cashLedgerRowsProvider);
                        },
                  icon: const Icon(Icons.north_east, size: 18),
                  label: const Text('Pay Credit'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: timelineAsync.when(
            data: (timelineRows) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: <Widget>[
                    if ((summaryAsync.valueOrNull ??
                            const <PartySummaryCardEntity>[])
                        .isNotEmpty) ...<Widget>[
                      LedgerSummaryCards(
                        summary: (summaryAsync.valueOrNull ??
                                const <PartySummaryCardEntity>[])
                            .firstWhere(
                          (summary) => selectedSupplierId == null || summary.partyId == selectedSupplierId,
                          orElse: () => (summaryAsync.valueOrNull ??
                              const <PartySummaryCardEntity>[]).first,
                        ),
                        balanceLabel: 'Net Payable',
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(child: LedgerTimelineTable(rows: timelineRows)),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _ReportErrorView(
              message: 'Failed to load supplier ledger timeline.',
              error: error,
              onRetry: () {
                ref.invalidate(supplierLedgerSummaryProvider);
                ref.invalidate(supplierLedgerTimelineProvider);
              },
            ),
          ),
        ),
      ],
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
            data: (rows) => Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Cash Flow components: Inflows (Cash Sales + Cash Collections), Outflows (Cash Refunds + Purchases Paid + Expenses)',
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
                        emptyMessage:
                            'No cash flow rows in selected date range.',
                        columnSpacing:
                            _reportTableLayoutFor(context).columnSpacing,
                        dataRowMinHeight:
                            _reportTableLayoutFor(context).dataRowMinHeight,
                        dataRowMaxHeight:
                            _reportTableLayoutFor(context).dataRowMaxHeight,
                        showCheckboxColumn: false,
                        columns: <DataColumn>[
                          DataColumn(
                              label: _styledTableHeaderCell(context, 'Day',
                                  width: 105)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Cash Sales In (PKR)',
                                  width: 140)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Collections In (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Total Cash In (PKR)',
                                  width: 140)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Cash Refunds Out (PKR)',
                                  width: 160)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Purchases Paid Out (PKR)',
                                  width: 175)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Expenses Out (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Total Cash Out (PKR)',
                                  width: 145)),
                          DataColumn(
                              label: _styledTableHeaderCell(
                                  context, 'Net Cash (PKR)',
                                  width: 130)),
                        ],
                        rows: rows.map((row) {
                          final colorScheme = Theme.of(context).colorScheme;
                          final isNegative = row.netCash < 0;
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(_styledTableCell(row.day, width: 105)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.cashSalesIn),
                                  width: 140)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(
                                      row.cashCollectionsIn),
                                  width: 145)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.totalCashIn),
                                  width: 140)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.cashRefundsOut),
                                  width: 160)),
                              DataCell(
                                _styledTableCell(
                                    FormattingHelpers.decimal(
                                        row.purchasePaymentsOut),
                                    width: 175),
                              ),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.expensesOut),
                                  width: 145)),
                              DataCell(_styledTableCell(
                                  FormattingHelpers.decimal(row.totalCashOut),
                                  width: 145)),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _styledStatusCell(
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
                    endDate == null
                        ? 'End Date'
                        : FormattingHelpers.dateYmd(endDate),
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
                        initialValue:
                            items.any((item) => item.value == selectedValue)
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
                      onChanged: (value) => ref
                          .read(expensesCategoryProvider.notifier)
                          .state = value,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: AppDataTable(
                  emptyMessage: 'No expenses found.',
                  columnSpacing: _reportTableLayoutFor(context).columnSpacing,
                  dataRowMinHeight:
                      _reportTableLayoutFor(context).dataRowMinHeight,
                  dataRowMaxHeight:
                      _reportTableLayoutFor(context).dataRowMaxHeight,
                  showCheckboxColumn: false,
                  columns: <DataColumn>[
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Date',
                            width: 110)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Category',
                            width: 150)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Amount (PKR)',
                            width: 130)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Notes',
                            width: 260)),
                    DataColumn(
                        label: _styledTableHeaderCell(context, 'Actions',
                            width: 150)),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(_styledTableCell(
                            FormattingHelpers.dateYmd(row.expenseDate),
                            width: 110)),
                        DataCell(_styledTableCell(row.category, width: 150)),
                        DataCell(_styledTableCell(
                            FormattingHelpers.decimal(row.amount),
                            width: 130)),
                        DataCell(
                            _styledTableCell(row.notes ?? '-', width: 260)),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Row(
                              children: <Widget>[
                                IconButton.filledTonal(
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    final saved = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _ExpenseFormDialog(
                                          initialExpense: row),
                                    );
                                    if (saved == true) {
                                      ref.invalidate(expensesRowsProvider);
                                      ref.invalidate(expenseCategoriesProvider);
                                      ref.invalidate(cashLedgerRowsProvider);
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  tooltip: 'Delete',
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
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) {
                                      return;
                                    }
                                    final repository = await ref
                                        .read(expenseRepositoryProvider.future);
                                    final result =
                                        await repository.deleteExpense(row.id);
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
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
    final notesError = NotesSafety.validate(_notesController.text,
        fieldLabel: 'Expense notes');
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
    AppNotifier.success(
        existing == null ? 'Expense added.' : 'Expense updated.');
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
                    columnSpacing: _reportTableLayoutFor(context).columnSpacing,
                    dataRowMinHeight:
                        _reportTableLayoutFor(context).dataRowMinHeight,
                    dataRowMaxHeight:
                        _reportTableLayoutFor(context).dataRowMaxHeight,
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

class _ReceiveCustomerCreditDialog extends ConsumerStatefulWidget {
  const _ReceiveCustomerCreditDialog({required this.customerId});

  final String? customerId;

  @override
  ConsumerState<_ReceiveCustomerCreditDialog> createState() =>
      _ReceiveCustomerCreditDialogState();
}

class _ReceiveCustomerCreditDialogState
    extends ConsumerState<_ReceiveCustomerCreditDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive Customer Credit'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Payment Method',
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
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Note (optional)',
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
          child: Text(_isSubmitting ? 'Saving...' : 'Receive'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final customerId = widget.customerId;
    if (customerId == null || customerId.trim().isEmpty) {
      AppNotifier.error('Select a customer first.');
      return;
    }
    final amount = FormattingHelpers.parseLocaleDecimal(_amountController.text);
    if (amount <= 0) {
      AppNotifier.error('Amount must be greater than zero.');
      return;
    }
    setState(() => _isSubmitting = true);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.receiveCustomerCredit(
      CustomerSettlementRequestPayload(
        customerId: customerId,
        amount: amount,
        paymentMethod: _paymentMethod,
        note: _noteController.text,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success('Customer credit received.');
    Navigator.of(context).pop();
  }
}

class _PaySupplierCreditDialog extends ConsumerStatefulWidget {
  const _PaySupplierCreditDialog({required this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<_PaySupplierCreditDialog> createState() =>
      _PaySupplierCreditDialogState();
}

class _PaySupplierCreditDialogState
    extends ConsumerState<_PaySupplierCreditDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay Supplier Credit'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Payment Method',
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
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Note (optional)',
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
          child: Text(_isSubmitting ? 'Saving...' : 'Pay'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final supplierId = widget.supplierId;
    if (supplierId == null || supplierId.trim().isEmpty) {
      AppNotifier.error('Select a supplier first.');
      return;
    }
    final amount = FormattingHelpers.parseLocaleDecimal(_amountController.text);
    if (amount <= 0) {
      AppNotifier.error('Amount must be greater than zero.');
      return;
    }
    setState(() => _isSubmitting = true);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.paySupplierCredit(
      SupplierSettlementRequestPayload(
        supplierId: supplierId,
        amount: amount,
        paymentMethod: _paymentMethod,
        note: _noteController.text,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success('Supplier credit paid.');
    Navigator.of(context).pop();
  }
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
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success('Return processed and stock restored.');
    ref.invalidate(customerLedgerSummaryProvider);
    ref.invalidate(customerLedgerTimelineProvider);
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
                    columnSpacing: _reportTableLayoutFor(context).columnSpacing,
                    dataRowMinHeight:
                        _reportTableLayoutFor(context).dataRowMinHeight,
                    dataRowMaxHeight:
                        _reportTableLayoutFor(context).dataRowMaxHeight,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _AnalyticsTable(
                          title: 'Issue Analysis',
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Issue')),
                            DataColumn(label: Text('Count')),
                          ],
                          rows: analytics.issueGroups
                              .map(
                                (g) => DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(g.issue)),
                                    DataCell(Text(g.count.toString())),
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
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Model')),
                            DataColumn(label: Text('Repairs')),
                          ],
                          rows: analytics.topModels
                              .map(
                                (m) => DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(m.model)),
                                    DataCell(Text(m.count.toString())),
                                  ],
                                ),
                              )
                              .toList(growable: false),
                          emptyMessage: 'No data.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AnalyticsTable(
                    title: 'Monthly Trend',
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Month')),
                      DataColumn(label: Text('Repairs')),
                      DataColumn(label: Text('Earnings')),
                    ],
                    rows: analytics.monthlyTrend
                        .map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(row.month)),
                              DataCell(Text(row.repairs.toString())),
                              DataCell(
                                Text(
                                  FormattingHelpers.currencyPkr(row.earnings),
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
  });

  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            AppDataTable(
              columnSpacing: _reportTableLayoutFor(context).columnSpacing,
              dataRowMinHeight: _reportTableLayoutFor(context).dataRowMinHeight,
              dataRowMaxHeight: _reportTableLayoutFor(context).dataRowMaxHeight,
              showCheckboxColumn: false,
              columns: columns,
              rows: rows,
              emptyMessage: emptyMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTableLayout {
  const _ReportTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  factory _ReportTableLayout.fromWidth(double width) {
    if (width >= 1600) {
      return const _ReportTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
      );
    }
    if (width >= 1220) {
      return const _ReportTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
      );
    }
    return const _ReportTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
    );
  }
}

_ReportTableLayout _reportTableLayoutFor(BuildContext context) {
  return _ReportTableLayout.fromWidth(MediaQuery.sizeOf(context).width);
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
