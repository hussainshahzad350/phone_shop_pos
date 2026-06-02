import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/report_calculation_service.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_query_providers.dart';

final dailySalesPageSummaryProvider = Provider<DailySalesPageSummary>((ref) {
  final rows = ref.watch(dateRangeSalesReportProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildDailySalesPageSummary(rows);
});

final dailySalesExportRowsProvider = Provider<List<List<String>>>((ref) {
  final rows = ref.watch(dateRangeSalesReportProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildDailySalesExportRows(rows);
});

final purchaseHistoryPageSummaryProvider =
    Provider<PurchaseHistoryPageSummary>((ref) {
  final rows = ref.watch(purchaseHistoryRowsProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildPurchaseHistoryPageSummary(rows);
});

final cashFlowPageSummaryProvider = Provider<CashFlowPageSummary>((ref) {
  final rows = ref.watch(cashLedgerRowsProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildCashFlowPageSummary(rows);
});

final profitExportRowsProvider = Provider<List<List<String>>>((ref) {
  final rows = ref.watch(profitReportRowsProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildProfitExportRows(rows);
});

final expensesTableSummaryProvider = Provider<ExpensesTableSummary>((ref) {
  final rows = ref.watch(expensesRowsProvider).valueOrNull ?? const [];
  return ReportCalculationService.buildExpensesTableSummary(rows);
});
