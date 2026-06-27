import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/services/export/csv_export_service.dart';
import 'package:phone_shop_pos/core/services/export/printable_report_service.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/providers/ledger_providers.dart';
import 'package:phone_shop_pos/modules/repairing/data/repositories/sqlite_repairing_repository.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_filter_providers.dart';
import 'package:phone_shop_pos/modules/reports/data/repositories/sqlite_expense_repository.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/customer_balance_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/daily_sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/low_stock_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_report_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sold_phone_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/stock_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/repositories/expense_repository.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/inventory_report_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/operations_workflow_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/sales_report_service.dart';

const int reportFilterOptionsLimit = 250;

final csvExportServiceProvider = Provider<CsvExportService>(
  (ref) => const FileCsvExportService(),
);

final printableReportServiceProvider = Provider<PrintableReportService>(
  (ref) => const PlainTextPrintableReportService(),
);

final salesReportServiceProvider = FutureProvider<SalesReportService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SalesReportService(appDatabase: appDatabase);
});

final inventoryReportServiceProvider =
    FutureProvider<InventoryReportService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return InventoryReportService(appDatabase: appDatabase);
});

final profitReportServiceProvider =
    FutureProvider<ProfitReportService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return ProfitReportService(appDatabase: appDatabase);
});

final operationsWorkflowServiceProvider =
    FutureProvider<OperationsWorkflowService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final ledgerPostingService = await ref.watch(ledgerPostingServiceProvider.future);
  return OperationsWorkflowService(
    appDatabase: appDatabase,
    ledgerPostingService: ledgerPostingService,
  );
});

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteExpenseRepository(appDatabase: appDatabase);
});

final dailySalesReportProvider =
    FutureProvider<List<DailySalesReportRowEntity>>((ref) async {
  final service = await ref.watch(salesReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getDailySalesReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final dateRangeSalesReportProvider =
    FutureProvider<List<SalesReportRowEntity>>((ref) async {
  final service = await ref.watch(salesReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getDateRangeSalesReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final soldPhonesReportProvider =
    FutureProvider<List<SoldPhoneReportRowEntity>>((ref) async {
  final service = await ref.watch(salesReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getSoldPhonesReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final profitReportRowsProvider = FutureProvider<List<ProfitRowEntity>>((ref) async {
  final service = await ref.watch(profitReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getProfitReportRows(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final profitReportProvider = FutureProvider<ProfitReportEntity>((ref) async {
  final service = await ref.watch(profitReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getProfitReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final currentStockReportProvider =
    FutureProvider<List<StockReportRowEntity>>((ref) async {
  final service = await ref.watch(inventoryReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getCurrentStockReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final customerBalanceReportProvider =
    FutureProvider<List<CustomerBalanceReportRowEntity>>((ref) async {
  final service = await ref.watch(inventoryReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getCustomerBalanceReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final lowStockReportProvider = FutureProvider<List<LowStockReportRowEntity>>((
  ref,
) async {
  final service = await ref.watch(inventoryReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getLowStockReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final reportCustomerOptionsProvider =
    FutureProvider.autoDispose<List<MapEntry<String, String>>>(
  (ref) async {
    final link = ref.keepAlive();
    Timer? disposeTimer;
    ref.onCancel(() {
      disposeTimer = Timer(const Duration(seconds: 45), link.close);
    });
    ref.onResume(() {
      disposeTimer?.cancel();
      disposeTimer = null;
    });
    ref.onDispose(() => disposeTimer?.cancel());

    final appDatabase = await ref.watch(appDatabaseProvider.future);
    final searchQuery = ref.watch(reportCustomerOptionSearchProvider).trim();
    final args = <Object?>[];
    final where = StringBuffer('is_active = 1');
    if (searchQuery.isNotEmpty) {
      final like = '%$searchQuery%';
      where.write(' AND (name LIKE ? OR phone LIKE ?)');
      args
        ..add(like)
        ..add(like);
    }

    final rows = await QueryDiagnostics.trace(
      label: 'reports.customer_filter_options',
      action: () => appDatabase.database.rawQuery(
        '''
      SELECT id, name
      FROM ${TableNames.customers}
      WHERE ${where.toString()}
      ORDER BY name COLLATE NOCASE ASC
      LIMIT ?
      ''',
        <Object?>[...args, reportFilterOptionsLimit],
      ),
    );

    return rows
        .map((row) => MapEntry(row['id'] as String, row['name'] as String))
        .toList(growable: false);
  },
);

final reportProductOptionsProvider =
    FutureProvider.autoDispose<List<MapEntry<String, String>>>(
  (ref) async {
    final link = ref.keepAlive();
    Timer? disposeTimer;
    ref.onCancel(() {
      disposeTimer = Timer(const Duration(seconds: 45), link.close);
    });
    ref.onResume(() {
      disposeTimer?.cancel();
      disposeTimer = null;
    });
    ref.onDispose(() => disposeTimer?.cancel());

    final appDatabase = await ref.watch(appDatabaseProvider.future);
    final searchQuery = ref.watch(reportProductOptionSearchProvider).trim();
    final args = <Object?>[];
    final where = StringBuffer('is_active = 1');
    if (searchQuery.isNotEmpty) {
      final like = '%$searchQuery%';
      where.write(' AND (name LIKE ? OR sku LIKE ? OR brand LIKE ?)');
      args
        ..add(like)
        ..add(like)
        ..add(like);
    }

    final rows = await QueryDiagnostics.trace(
      label: 'reports.product_filter_options',
      action: () => appDatabase.database.rawQuery(
        '''
      SELECT id, name
      FROM ${TableNames.productModels}
      WHERE ${where.toString()}
      ORDER BY name COLLATE NOCASE ASC
      LIMIT ?
      ''',
        <Object?>[...args, reportFilterOptionsLimit],
      ),
    );

    return rows
        .map((row) => MapEntry(row['id'] as String, row['name'] as String))
        .toList(growable: false);
  },
);

final salesInvoiceDetailProvider =
    FutureProvider.autoDispose.family<SalesInvoiceDetailEntity?, String>((
  ref,
  saleId,
) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.getSalesInvoiceDetail(saleId);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final purchaseHistoryRowsProvider =
    FutureProvider<List<PurchaseHistoryRowEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.searchPurchaseHistory(
    supplierQuery: ref.watch(purchaseHistorySupplierQueryProvider),
    startDate: ref.watch(purchaseHistoryStartDateProvider),
    endDate: ref.watch(purchaseHistoryEndDateProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final purchaseHistoryDetailProvider =
    FutureProvider.autoDispose.family<PurchaseHistoryDetailEntity?, String>((
  ref,
  purchaseId,
) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.getPurchaseHistoryDetail(purchaseId);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final supplierLedgerRowsProvider =
    FutureProvider<List<SupplierLedgerRowEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.getSupplierLedger(
    startDate: ref.watch(purchaseHistoryStartDateProvider),
    endDate: ref.watch(purchaseHistoryEndDateProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final customerLedgerSummaryProvider =
    FutureProvider<List<PartySummaryCardEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.fetchCustomerLedgerSummary(
    customerId: ref.watch(customerLedgerTimelineCustomerIdProvider),
    outstandingOnly: ref.watch(customerLedgerTimelineOutstandingOnlyProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final supplierLedgerSummaryProvider =
    FutureProvider<List<PartySummaryCardEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.fetchSupplierLedgerSummary(
    supplierId: ref.watch(supplierLedgerTimelineSupplierIdProvider),
    outstandingOnly: ref.watch(supplierLedgerTimelineOutstandingOnlyProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final customerLedgerTimelineProvider =
    FutureProvider<List<LedgerTimelineRowEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.fetchCustomerLedgerTimeline(
    customerId: ref.watch(customerLedgerTimelineCustomerIdProvider),
    ledgerType: ref.watch(customerLedgerTimelineTypeProvider),
    startDate: ref.watch(customerLedgerTimelineStartDateProvider),
    endDate: ref.watch(customerLedgerTimelineEndDateProvider),
    outstandingOnly: ref.watch(customerLedgerTimelineOutstandingOnlyProvider),
    includePaymentHistory: ref.watch(customerLedgerTimelinePaymentHistoryProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final supplierLedgerTimelineProvider =
    FutureProvider<List<LedgerTimelineRowEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.fetchSupplierLedgerTimeline(
    supplierId: ref.watch(supplierLedgerTimelineSupplierIdProvider),
    ledgerType: ref.watch(supplierLedgerTimelineTypeProvider),
    startDate: ref.watch(supplierLedgerTimelineStartDateProvider),
    endDate: ref.watch(supplierLedgerTimelineEndDateProvider),
    outstandingOnly: ref.watch(supplierLedgerTimelineOutstandingOnlyProvider),
    includePaymentHistory: ref.watch(supplierLedgerTimelinePaymentHistoryProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final cashLedgerRowsProvider = FutureProvider<List<CashLedgerRowEntity>>((
  ref,
) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.getCashLedger(
    startDate: ref.watch(cashLedgerStartDateProvider),
    endDate: ref.watch(cashLedgerEndDateProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final expensesRowsProvider = FutureProvider<List<ExpenseEntity>>((ref) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  final result = await repository.getExpenses(
    startDate: ref.watch(expensesStartDateProvider),
    endDate: ref.watch(expensesEndDateProvider),
    category: ref.watch(expensesCategoryProvider),
    paymentMethod: ref.watch(expensesPaymentMethodProvider),
    searchRemarks: ref.watch(expensesSearchRemarksProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final expenseCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  final result = await repository.getExpenseCategories();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final expenseAnalyticsSummaryProvider =
    FutureProvider<ExpenseAnalyticsSummary>((ref) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  final startDate = ref.watch(expensesStartDateProvider);
  final endDate = ref.watch(expensesEndDateProvider);
  final result = await repository.getAnalyticsSummary(
    startDate: startDate,
    endDate: endDate,
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final stockAdjustmentHistoryProvider =
    FutureProvider<List<StockAdjustmentHistoryRowEntity>>((ref) async {
  final service = await ref.watch(operationsWorkflowServiceProvider.future);
  final result = await service.getStockAdjustments(limit: 50);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final reportRepairAnalyticsProvider =
    FutureProvider<RepairAnalyticsEntity>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final repository = SqliteRepairingRepository(appDatabase: appDatabase);
  final result = await repository.getRepairAnalytics(
    startDate: ref.watch(reportRepairAnalyticsStartDateProvider),
    endDate: ref.watch(reportRepairAnalyticsEndDateProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});
