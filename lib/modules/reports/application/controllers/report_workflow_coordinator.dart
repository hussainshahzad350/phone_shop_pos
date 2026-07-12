import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/customers/presentation/providers/customer_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/imei_management_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/product_management_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_query_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_query_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/modules/suppliers/presentation/providers/supplier_info_providers.dart';

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
    refreshDashboard();
  }

  /// Invalidates all dashboard KPI/stock providers so the dashboard reflects
  /// the latest data without requiring an app restart.
  void refreshDashboard() {
    _ref.invalidate(dashboardKpisProvider);
    _ref.invalidate(dashboardRecentSalesProvider);
    _ref.invalidate(dashboardLowStockProvider);
    _ref.invalidate(dashboardAllLowStockProvider);
    _ref.invalidate(dashboardBrandStockProvider);
    _ref.invalidate(dashboardDealerStockBreakdownProvider);
    _ref.invalidate(dashboardModelImeiStockProvider);
    _ref.invalidate(dashboardPendingReturnsProvider);
    _ref.invalidate(dashboardTodaySalesDetailsProvider);
    _ref.invalidate(dashboardPendingBalanceDetailsProvider);
    refreshProductAndStockData();
  }

  /// Invalidates every screen's view of product/stock data (Master Data
  /// products list, Sale Screen product grid, Inventory stock table, and the
  /// per-model IMEI management list) so a change made from any one of them —
  /// price, IMEI, purchase info — is immediately visible on the others. This
  /// is the single source-of-truth propagation point; call sites should not
  /// invalidate these providers individually.
  void refreshProductAndStockData() {
    _ref.invalidate(managedProductsProvider);
    _ref.invalidate(productSearchResultsProvider);
    _ref.invalidate(productStockInfoProvider);
    _ref.invalidate(stockRowsProvider);
    _ref.invalidate(imeiListForModelProvider);
    _ref.invalidate(supplierSummariesProvider);
    _ref.invalidate(supplierPurchaseHistoryProvider);
  }

  /// Call after any supplier master-data mutation (create/edit/archive/
  /// delete) so the supplier list/search, ledger, and any report carrying a
  /// denormalized supplier name (Purchase History) stay in sync without an
  /// app restart. This is the single source-of-truth propagation point for
  /// supplier changes; call sites should not invalidate these individually.
  void refreshAfterSupplierChange() {
    _ref.invalidate(supplierListProvider);
    _ref.invalidate(supplierSearchResultsProvider);
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(purchaseHistoryRowsProvider);
    refreshDashboard();
  }

  /// Call after any customer master-data mutation (create/edit/archive/
  /// delete) so the customer list/search, ledger, and any report carrying a
  /// denormalized customer name (Daily Sales) stay in sync without an app
  /// restart. This is the single source-of-truth propagation point for
  /// customer changes; call sites should not invalidate these individually.
  void refreshAfterCustomerChange() {
    _ref.invalidate(customerListProvider);
    _ref.invalidate(customerSearchResultsProvider);
    _ref.invalidate(reportCustomerOptionsProvider);
    _ref.invalidate(customerLedgerSummaryProvider);
    _ref.invalidate(dailySalesReportProvider);
    _ref.invalidate(dateRangeSalesReportProvider);
    refreshDashboard();
  }

  /// Call after any inventory mutation (IMEI add/delete/edit, stock
  /// adjustment) so the dashboard and stock/profit-related reports stay in
  /// sync without requiring an app restart.
  void refreshInventoryAfterChange() {
    refreshDashboard();
    _ref.invalidate(stockAdjustmentHistoryProvider);
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(profitReportProvider);
    _ref.invalidate(profitReportRowsProvider);
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
    refreshDashboard();
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
    refreshDashboard();
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
    refreshDashboard();
  }

  void refreshPurchaseAfterCompletion() {
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(supplierLedgerRowsProvider);
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
    refreshDashboard();
  }

  void refreshPurchaseAfterReturn(String purchaseId) {
    _ref.invalidate(purchaseHistoryRowsProvider);
    _ref.invalidate(purchaseHistoryDetailProvider(purchaseId));
    _ref.invalidate(supplierLedgerSummaryProvider);
    _ref.invalidate(supplierLedgerTimelineProvider);
    _ref.invalidate(cashLedgerRowsProvider);
    refreshDashboard();
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
