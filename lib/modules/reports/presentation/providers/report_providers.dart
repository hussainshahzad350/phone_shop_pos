import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/customer_balance_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/daily_sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/low_stock_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_report_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sold_phone_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/stock_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/inventory_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/sales_report_service.dart';

enum ReportsTab {
  dailySales,
  dateRangeSales,
  profit,
  soldPhones,
  currentStock,
  customerBalance,
  lowStock,
}

class ReportFilterNotifier extends StateNotifier<ReportFilterEntity> {
  ReportFilterNotifier() : super(const ReportFilterEntity());

  void setStartDate(DateTime? date) {
    state = state.copyWith(startDate: date, page: 1);
  }

  void setEndDate(DateTime? date) {
    state = state.copyWith(endDate: date, page: 1);
  }

  void setCustomerId(String? customerId) {
    if (customerId == null || customerId.trim().isEmpty) {
      state = state.copyWith(clearCustomerId: true, page: 1);
      return;
    }
    state = state.copyWith(customerId: customerId.trim(), page: 1);
  }

  void setProductModelId(String? productModelId) {
    if (productModelId == null || productModelId.trim().isEmpty) {
      state = state.copyWith(clearProductModelId: true, page: 1);
      return;
    }
    state = state.copyWith(productModelId: productModelId.trim(), page: 1);
  }

  void setStatus(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatus: true, page: 1);
      return;
    }
    state = state.copyWith(status: status, page: 1);
  }

  void setPaymentMethod(String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) {
      state = state.copyWith(clearPaymentMethod: true, page: 1);
      return;
    }
    state = state.copyWith(paymentMethod: paymentMethod, page: 1);
  }

  void nextPage() {
    state = state.copyWith(page: state.page + 1);
  }

  void previousPage() {
    if (state.page <= 1) {
      return;
    }
    state = state.copyWith(page: state.page - 1);
  }

  void setPageSize(int pageSize) {
    state = state.copyWith(pageSize: pageSize, page: 1);
  }

  void clearAll() {
    state = const ReportFilterEntity();
  }
}

final selectedReportsTabProvider = StateProvider<ReportsTab>(
  (ref) => ReportsTab.dailySales,
);

final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilterEntity>(
      (ref) => ReportFilterNotifier(),
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

final profitReportServiceProvider = FutureProvider<ProfitReportService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return ProfitReportService(appDatabase: appDatabase);
});

final dailySalesReportProvider =
    FutureProvider<List<DailySalesReportRowEntity>>((ref) async {
      final service = await ref.watch(salesReportServiceProvider.future);
      final filter = ref.watch(reportFilterProvider);
      final result = await service.getDailySalesReport(filter);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <DailySalesReportRowEntity>[],
      );
    });

final dateRangeSalesReportProvider =
    FutureProvider<List<SalesReportRowEntity>>((ref) async {
      final service = await ref.watch(salesReportServiceProvider.future);
      final filter = ref.watch(reportFilterProvider);
      final result = await service.getDateRangeSalesReport(filter);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <SalesReportRowEntity>[],
      );
    });

final soldPhonesReportProvider =
    FutureProvider<List<SoldPhoneReportRowEntity>>((ref) async {
      final service = await ref.watch(salesReportServiceProvider.future);
      final filter = ref.watch(reportFilterProvider);
      final result = await service.getSoldPhonesReport(filter);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <SoldPhoneReportRowEntity>[],
      );
    });

final profitReportProvider = FutureProvider<ProfitReportEntity>((ref) async {
  final service = await ref.watch(profitReportServiceProvider.future);
  final filter = ref.watch(reportFilterProvider);
  final result = await service.getProfitReport(filter);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const ProfitReportEntity(
      totalRevenue: 0,
      totalCost: 0,
      totalProfit: 0,
    ),
  );
});

final currentStockReportProvider =
    FutureProvider<List<StockReportRowEntity>>((ref) async {
      final service = await ref.watch(inventoryReportServiceProvider.future);
      final filter = ref.watch(reportFilterProvider);
      final result = await service.getCurrentStockReport(filter);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <StockReportRowEntity>[],
      );
    });

final customerBalanceReportProvider =
    FutureProvider<List<CustomerBalanceReportRowEntity>>((ref) async {
      final service = await ref.watch(inventoryReportServiceProvider.future);
      final filter = ref.watch(reportFilterProvider);
      final result = await service.getCustomerBalanceReport(filter);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <CustomerBalanceReportRowEntity>[],
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
    onFailure: (_) => const <LowStockReportRowEntity>[],
  );
});

final reportCustomerOptionsProvider = FutureProvider<List<MapEntry<String, String>>>(
  (ref) async {
    final appDatabase = await ref.watch(appDatabaseProvider.future);
    final rows = await appDatabase.database.rawQuery(
      '''
      SELECT id, name
      FROM customers
      ORDER BY name COLLATE NOCASE ASC
      ''',
    );

    return rows
        .map((row) => MapEntry(row['id'] as String, row['name'] as String))
        .toList(growable: false);
  },
);

final reportProductOptionsProvider = FutureProvider<List<MapEntry<String, String>>>(
  (ref) async {
    final appDatabase = await ref.watch(appDatabaseProvider.future);
    final rows = await appDatabase.database.rawQuery(
      '''
      SELECT id, name
      FROM product_models
      WHERE is_active = 1
      ORDER BY name COLLATE NOCASE ASC
      ''',
    );

    return rows
        .map((row) => MapEntry(row['id'] as String, row['name'] as String))
        .toList(growable: false);
  },
);
