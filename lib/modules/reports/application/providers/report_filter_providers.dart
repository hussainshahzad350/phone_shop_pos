import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';

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
    final normalized = PaymentMethod.normalizeNullable(paymentMethod);
    if (normalized == null) {
      state = state.copyWith(clearPaymentMethod: true, page: 1);
      return;
    }
    state = state.copyWith(paymentMethod: normalized, page: 1);
  }

  void setItemType(String? itemType) {
    if (itemType == null || itemType.isEmpty) {
      state = state.copyWith(clearItemType: true, page: 1);
      return;
    }
    state = state.copyWith(itemType: itemType, page: 1);
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

final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilterEntity>(
  (ref) => ReportFilterNotifier(),
);

final reportCustomerOptionSearchProvider = StateProvider<String>((ref) => '');
final reportProductOptionSearchProvider = StateProvider<String>((ref) => '');

final salesHistoryInvoiceQueryProvider = StateProvider<String>((ref) => '');
final salesHistoryCustomerQueryProvider = StateProvider<String>((ref) => '');
final salesHistoryStartDateProvider = StateProvider<DateTime?>((ref) => null);
final salesHistoryEndDateProvider = StateProvider<DateTime?>((ref) => null);

final purchaseHistorySupplierQueryProvider = StateProvider<String>((ref) => '');
final purchaseHistoryStartDateProvider =
    StateProvider<DateTime?>((ref) => null);
final purchaseHistoryEndDateProvider = StateProvider<DateTime?>((ref) => null);

final customerLedgerTimelineCustomerIdProvider =
    StateProvider<String?>((ref) => null);
final customerLedgerTimelineTypeProvider = StateProvider<String?>((ref) => null);
final customerLedgerTimelineOutstandingOnlyProvider =
    StateProvider<bool>((ref) => false);
final customerLedgerTimelinePaymentHistoryProvider =
    StateProvider<bool>((ref) => true);
final customerLedgerTimelineStartDateProvider =
    StateProvider<DateTime?>((ref) => null);
final customerLedgerTimelineEndDateProvider =
    StateProvider<DateTime?>((ref) => null);

final supplierLedgerTimelineSupplierIdProvider =
    StateProvider<String?>((ref) => null);
final supplierLedgerTimelineTypeProvider = StateProvider<String?>((ref) => null);
final supplierLedgerTimelineOutstandingOnlyProvider =
    StateProvider<bool>((ref) => false);
final supplierLedgerTimelinePaymentHistoryProvider =
    StateProvider<bool>((ref) => true);
final supplierLedgerTimelineStartDateProvider =
    StateProvider<DateTime?>((ref) => null);
final supplierLedgerTimelineEndDateProvider =
    StateProvider<DateTime?>((ref) => null);

final cashLedgerStartDateProvider = StateProvider<DateTime?>((ref) => null);
final cashLedgerEndDateProvider = StateProvider<DateTime?>((ref) => null);

final expensesStartDateProvider = StateProvider<DateTime?>((ref) => null);
final expensesEndDateProvider = StateProvider<DateTime?>((ref) => null);
final expensesCategoryProvider = StateProvider<String>((ref) => '');
final expensesPaymentMethodProvider = StateProvider<String>((ref) => '');
final expensesSearchRemarksProvider = StateProvider<String>((ref) => '');

final reportRepairAnalyticsStartDateProvider =
    StateProvider<DateTime?>((ref) => null);
final reportRepairAnalyticsEndDateProvider =
    StateProvider<DateTime?>((ref) => null);
