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
import 'package:phone_shop_pos/modules/reports/presentation/screens/customer_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/supplier_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_header.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_pagination_bar.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_tab_chips.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/daily_sales_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/cash_flow_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/profit_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/repair_analytics_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/customer_ledger_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/purchase_history_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/supplier_ledger_tab.dart';
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

  Future<void> _showInvoiceDialog(
    BuildContext context,
    String saleId,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SalesInvoiceDialog(saleId: saleId),
    );
  }

  Future<void> _reprint(
    WidgetRef ref,
    String jobId,
  ) async {
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

  Future<void> _showPurchaseDetailDialog(
    BuildContext context,
    String purchaseId,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PurchaseDetailDialog(purchaseId: purchaseId),
    );
  }

  Future<void> _openCustomerLedger(
    BuildContext context,
    WidgetRef ref,
    PartySummaryCardEntity summary,
  ) async {
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

  Future<void> _openSupplierLedger(
    BuildContext context,
    WidgetRef ref,
    PartySummaryCardEntity summary,
  ) async {
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
                ReportHeader(
                  onRefresh: () => _refreshAll(ref),
                ),
                const SizedBox(height: 8),
                ReportTabChips(
                  selectedTab: tab,
                  labelFor: _tabLabel,
                  onSelectTab: (item) => ref
                      .read(selectedReportsTabProvider.notifier)
                      .state = item,
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
                  child: _ReportContent(
                    tab: tab,
                    onOpenInvoice: (saleId) =>
                        _showInvoiceDialog(context, saleId),
                    onOpenPurchaseDetail: (purchaseId) =>
                        _showPurchaseDetailDialog(context, purchaseId),
                    onReprint: (jobId) => _reprint(ref, jobId),
                    onOpenCustomerLedger: (summary) =>
                        _openCustomerLedger(context, ref, summary),
                    onOpenSupplierLedger: (summary) =>
                        _openSupplierLedger(context, ref, summary),
                  ),
                ),
                if (_usesLegacyFilters(tab)) ...<Widget>[
                  const SizedBox(height: 8),
                  ReportPaginationBar(
                    filter: filter,
                    canGoNextPage: canGoNextPage,
                    onPreviousPage: () =>
                        ref.read(reportFilterProvider.notifier).previousPage(),
                    onNextPage: () =>
                        ref.read(reportFilterProvider.notifier).nextPage(),
                    onPageSizeChanged: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setPageSize(value),
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
  const _ReportContent({
    required this.tab,
    required this.onOpenInvoice,
    required this.onOpenPurchaseDetail,
    required this.onReprint,
    required this.onOpenCustomerLedger,
    required this.onOpenSupplierLedger,
  });

  final ReportsTab tab;
  final Future<void> Function(String saleId) onOpenInvoice;
  final Future<void> Function(String purchaseId) onOpenPurchaseDetail;
  final Future<void> Function(String jobId) onReprint;
  final Future<void> Function(PartySummaryCardEntity summary)
      onOpenCustomerLedger;
  final Future<void> Function(PartySummaryCardEntity summary)
      onOpenSupplierLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab == ReportsTab.dailySales) {
      return DailySalesTab(onOpenInvoice: onOpenInvoice, onReprint: onReprint);
    }

    if (tab == ReportsTab.profit) {
      return const ProfitTab();
    }

    if (tab == ReportsTab.customerLedger) {
      return CustomerLedgerTab(onOpenLedger: onOpenCustomerLedger);
    }

    if (tab == ReportsTab.dailyPurchase) {
      return PurchaseHistoryTab(
        onOpenPurchaseDetail: onOpenPurchaseDetail,
      );
    }

    if (tab == ReportsTab.supplierLedger) {
      return SupplierLedgerTab(onOpenLedger: onOpenSupplierLedger);
    }

    if (tab == ReportsTab.cashFlow) {
      return const CashFlowTab();
    }

    if (tab == ReportsTab.expenses) {
      return const _ExpensesView();
    }

    if (tab == ReportsTab.repairAnalytics) {
      return const RepairAnalyticsTab();
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
        ReportSummaryRow(
          children: <Widget>[
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Total Sales (page)',
                value: FormattingHelpers.currencyPkr(sumTotal),
              ),
            ),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Invoices (page)',
                value: totalInvoices.toString(),
                color: Colors.indigo,
              ),
            ),
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
                    ReportDateFilterButton(
                      icon: Icons.calendar_today,
                      iconSize: 16,
                      emptyLabel: 'Start Date',
                      selectedDate: startDate,
                      initialDate: startDate ?? DateTime.now(),
                      onPicked: (picked) {
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesStartDateProvider.notifier).state =
                            picked;
                      },
                    ),
                    ReportDateFilterButton(
                      icon: Icons.event,
                      iconSize: 16,
                      emptyLabel: 'End Date',
                      selectedDate: endDate,
                      initialDate: endDate ?? DateTime.now(),
                      onPicked: (picked) {
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesEndDateProvider.notifier).state =
                            picked;
                      },
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
                    if (detail.purchase.sellerName?.trim().isNotEmpty == true)
                      Text('Seller: ${detail.purchase.sellerName}'),
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
                      DataColumn(label: Text('Returns')),
                      DataColumn(label: Text('Actions')),
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
                          DataCell(Text(item.returnedQty.toString())),
                          DataCell(
                            item.returnableQty > 0
                                ? TextButton(
                                    onPressed: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (context) =>
                                            _ReturnPurchaseItemDialog(
                                          purchaseId:
                                              detail.purchase.purchaseId,
                                          item: item,
                                        ),
                                      );
                                    },
                                    child: const Text('Return'),
                                  )
                                : const SizedBox.shrink(),
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

class _ReturnPurchaseItemDialog extends ConsumerStatefulWidget {
  const _ReturnPurchaseItemDialog({
    required this.purchaseId,
    required this.item,
  });

  final String purchaseId;
  final PurchaseHistoryItemEntity item;

  @override
  ConsumerState<_ReturnPurchaseItemDialog> createState() =>
      _ReturnPurchaseItemDialogState();
}

class _ReturnPurchaseItemDialogState
    extends ConsumerState<_ReturnPurchaseItemDialog> {
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController(text: 'damage');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.item.hasImei ? '1' : '';
  }

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
      title: const Text('Return Purchase Item'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Returning: ${widget.item.productName}'),
            if (widget.item.hasImei) Text('IMEI: ${widget.item.imei}'),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              decoration: InputDecoration(
                labelText: 'Quantity (max ${widget.item.returnableQty})',
              ),
              keyboardType: TextInputType.number,
              readOnly: widget.item.hasImei,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm Return'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final qty =
        widget.item.hasImei ? 1 : int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0 || qty > widget.item.returnableQty) {
      AppNotifier.error('Invalid return quantity.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppNotifier.error('Reason is required.');
      return;
    }

    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.processPurchaseReturn(
      purchaseId: widget.purchaseId,
      item: widget.item,
      quantity: qty,
      reason: reason,
      notes: _notesController.text,
    );

    if (!mounted) {
      return;
    }

    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }

    AppNotifier.success('Purchase return processed successfully.');
    ref.invalidate(purchaseHistoryRowsProvider);
    ref.invalidate(purchaseHistoryDetailProvider(widget.purchaseId));
    ref.invalidate(supplierLedgerSummaryProvider);
    ref.invalidate(supplierLedgerTimelineProvider);
    ref.invalidate(cashLedgerRowsProvider);
    Navigator.of(context).pop();
  }
}

class _RefreshReportsIntent extends Intent {
  const _RefreshReportsIntent();
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
