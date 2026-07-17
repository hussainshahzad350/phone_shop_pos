import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/purchase_detail_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/sales_invoice_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/customer_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/supplier_ledger_detail_screen.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/cash_flow_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/customer_ledger_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/daily_sales_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/expenses_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/profit_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/purchase_history_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/dealer_issues_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/repair_analytics_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/supplier_ledger_tab.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_filter_bar_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_header.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_pagination_bar.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_tab_chips.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
    ref.read(reportWorkflowCoordinatorProvider).refreshAll();
  }

  Future<void> _showInvoiceDialog(BuildContext context, String saleId) async {
    await showDialog<void>(
      context: context,
      builder: (context) => SalesInvoiceDialog(saleId: saleId),
    );
  }

  Future<void> _cancelSale(
    BuildContext context,
    WidgetRef ref,
    String saleId,
    String status,
  ) async {
    if (status == 'void') {
      AppNotifier.warning('This sale is already cancelled.');
      return;
    }
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel Sale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This will void the sale and restore stock. Enter a reason:',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                ),
                autofocus: true,
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        AppNotifier.warning('Please provide a reason for cancelling.');
        return;
      }
      final service = await ref.read(salesServiceProvider.future);
      final result = await service.voidSale(saleId: saleId, voidReason: reason);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) {
          AppNotifier.success('Sale cancelled successfully.');
          ref
              .read(reportWorkflowCoordinatorProvider)
              .refreshSalesAfterReturn(saleId: saleId);
          _invalidateStockViews(ref);
        },
        onFailure: AppNotifier.errorFromAppError,
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _reprint(WidgetRef ref, String jobId) async {
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

  Future<void> _cancelPurchase(
    BuildContext context,
    WidgetRef ref,
    String purchaseId,
    String status,
  ) async {
    if (status == 'void') {
      AppNotifier.warning('This purchase is already cancelled.');
      return;
    }
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel Purchase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This will void the purchase and reverse received stock and '
                'supplier ledger. Enter a reason:',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                ),
                autofocus: true,
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        AppNotifier.warning('Please provide a reason for cancelling.');
        return;
      }
      final service = await ref.read(purchaseServiceProvider.future);
      final result = await service.voidPurchase(
        purchaseId: purchaseId,
        voidReason: reason,
      );
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) {
          AppNotifier.success('Purchase cancelled successfully.');
          ref
              .read(reportWorkflowCoordinatorProvider)
              .refreshPurchaseAfterReturn(purchaseId);
          _invalidateStockViews(ref);
        },
        onFailure: AppNotifier.errorFromAppError,
      );
    } finally {
      reasonController.dispose();
    }
  }

  /// Refresh the Inventory and Dashboard views after a void reverses stock.
  /// The report workflow coordinator only refreshes report-scoped providers,
  /// so without this the cancelled stock keeps showing on the Inventory screen
  /// and Dashboard KPIs (which are kept alive by the navigation shell).
  void _invalidateStockViews(WidgetRef ref) {
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockRowsProvider);
    ref.invalidate(lowStockProvider);
    refreshDashboardData(ref);
  }

  Future<void> _showPurchaseDetailDialog(
    BuildContext context,
    String purchaseId,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => PurchaseDetailDialog(purchaseId: purchaseId),
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
        ref.read(reportWorkflowCoordinatorProvider).refreshCustomerLedgerReports();
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
        ref.read(reportWorkflowCoordinatorProvider).refreshSupplierLedgerReports();
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ReportHeader(onRefresh: () => _refreshAll(ref)),
                const SizedBox(height: AppSpacing.sm),
                ReportTabChips(
                  selectedTab: tab,
                  labelFor: _tabLabel,
                  onSelectTab: (item) =>
                      ref.read(selectedReportsTabProvider.notifier).state = item,
                ),
                const SizedBox(height: AppSpacing.sm),
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
                    onStartDate: (date) =>
                        ref.read(reportFilterProvider.notifier).setStartDate(date),
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
                    onItemType: (value) => ref
                        .read(reportFilterProvider.notifier)
                        .setItemType(value),
                    onClear: () =>
                        ref.read(reportFilterProvider.notifier).clearAll(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Expanded(
                  child: _ReportContent(
                    tab: tab,
                    onOpenInvoice: (saleId) =>
                        _showInvoiceDialog(context, saleId),
                    onOpenPurchaseDetail: (purchaseId) =>
                        _showPurchaseDetailDialog(context, purchaseId),
                    onCancelPurchase: (purchaseId, status) =>
                        _cancelPurchase(context, ref, purchaseId, status),
                    onReprint: (jobId) => _reprint(ref, jobId),
                    onCancelSale: (saleId, status) =>
                        _cancelSale(context, ref, saleId, status),
                    onOpenCustomerLedger: (summary) =>
                        _openCustomerLedger(context, ref, summary),
                    onOpenSupplierLedger: (summary) =>
                        _openSupplierLedger(context, ref, summary),
                  ),
                ),
                if (_usesLegacyFilters(tab)) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  ReportPaginationBar(
                    filter: filter,
                    canGoNextPage: canGoNextPage,
                    onPreviousPage: () =>
                        ref.read(reportFilterProvider.notifier).previousPage(),
                    onNextPage: () =>
                        ref.read(reportFilterProvider.notifier).nextPage(),
                    onPageSizeChanged: (value) =>
                        ref.read(reportFilterProvider.notifier).setPageSize(value),
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
      case ReportsTab.dealerIssues:
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
    required this.onCancelPurchase,
    required this.onReprint,
    required this.onCancelSale,
    required this.onOpenCustomerLedger,
    required this.onOpenSupplierLedger,
  });

  final ReportsTab tab;
  final Future<void> Function(String saleId) onOpenInvoice;
  final Future<void> Function(String purchaseId) onOpenPurchaseDetail;
  final Future<void> Function(String purchaseId, String status)
      onCancelPurchase;
  final Future<void> Function(String jobId) onReprint;
  final Future<void> Function(String saleId, String status) onCancelSale;
  final Future<void> Function(PartySummaryCardEntity summary)
      onOpenCustomerLedger;
  final Future<void> Function(PartySummaryCardEntity summary)
      onOpenSupplierLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (tab) {
      case ReportsTab.dailySales:
        return DailySalesTab(
          onOpenInvoice: onOpenInvoice,
          onReprint: onReprint,
          onCancelSale: onCancelSale,
        );
      case ReportsTab.profit:
        return const ProfitTab();
      case ReportsTab.customerLedger:
        return CustomerLedgerTab(onOpenLedger: onOpenCustomerLedger);
      case ReportsTab.dailyPurchase:
        return PurchaseHistoryTab(
          onOpenPurchaseDetail: onOpenPurchaseDetail,
          onCancelPurchase: onCancelPurchase,
        );
      case ReportsTab.supplierLedger:
        return SupplierLedgerTab(onOpenLedger: onOpenSupplierLedger);
      case ReportsTab.cashFlow:
        return const CashFlowTab();
      case ReportsTab.expenses:
        return const ExpensesTab();
      case ReportsTab.repairAnalytics:
        return const RepairAnalyticsTab();
      case ReportsTab.dealerIssues:
        return const DealerIssuesTab();
    }
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
    case ReportsTab.dealerIssues:
      return 'Dealer Issues';
  }
}
