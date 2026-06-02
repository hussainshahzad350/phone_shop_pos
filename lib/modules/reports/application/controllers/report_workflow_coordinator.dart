import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_query_providers.dart';

final reportWorkflowCoordinatorProvider = Provider<ReportWorkflowCoordinator>(
  (ref) => ReportWorkflowCoordinator(ref),
);

class ReportWorkflowCoordinator {
  ReportWorkflowCoordinator(this._ref);

  final Ref _ref;

  void refreshAll() {
    _ref.invalidate(dailySalesReportProvider);
    _ref.invalidate(dateRangeSalesReportProvider);
    _ref.invalidate(profitReportProvider);
    _ref.invalidate(customerBalanceReportProvider);
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(supplierLedgerRowsProvider);
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(customerLedgerTimelineProvider);
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
    _ref.invalidate(expensesRowsProvider);
    _ref.invalidate(expenseCategoriesProvider);
    _ref.invalidate(expenseAnalyticsSummaryProvider);
    _ref.invalidate(stockAdjustmentHistoryProvider);
    _ref.invalidate(reportRepairAnalyticsProvider);
  }

  void refreshSalesAfterCompletion() {
    _ref.invalidate(dailySalesReportProvider);
    _ref.invalidate(dateRangeSalesReportProvider);
    _ref.invalidate(soldPhonesReportProvider);
    _ref.invalidate(profitReportProvider);
    _ref.invalidate(profitReportRowsProvider);
    _ref.invalidate(customerBalanceReportProvider);
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(customerLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshSalesAfterReturn({String? saleId}) {
    if (saleId != null) {
      _ref.invalidate(salesInvoiceDetailProvider(saleId));
    }
    _ref.invalidate(dailySalesReportProvider);
    _ref.invalidate(dateRangeSalesReportProvider);
    _ref.invalidate(profitReportProvider);
    _ref.invalidate(profitReportRowsProvider);
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(customerLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshSalesInvoiceDetail(String saleId) {
    _ref.invalidate(salesInvoiceDetailProvider(saleId));
  }

  void refreshAfterPaymentCollection() {
    _ref.invalidate(dateRangeSalesReportProvider);
    _ref.invalidate(customerBalanceReportProvider);
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(customerLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshPurchaseAfterCompletion() {
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(supplierLedgerRowsProvider);
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshPurchaseAfterReturn(String purchaseId) {
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(purchaseHistoryDetailProvider(purchaseId));
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshCustomerLedgerReports() {
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(customerLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshSupplierLedgerReports() {
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }

  void refreshExpenseReports() {
    _ref.invalidate(expensesRowsProvider);
    _ref.invalidate(expenseCategoriesProvider);
    _ref.invalidate(expenseAnalyticsSummaryProvider);
    _ref.invalidate(cashLedgerRowsProvider);
  }
}
