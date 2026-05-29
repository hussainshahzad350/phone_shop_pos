import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

/// Binds timeline providers to a party while a detail screen is open.
void bindCustomerLedgerDetailScope(WidgetRef ref, String customerId) {
  ref.read(customerLedgerTimelineCustomerIdProvider.notifier).state =
      customerId;
}

void bindSupplierLedgerDetailScope(WidgetRef ref, String supplierId) {
  ref.read(supplierLedgerTimelineSupplierIdProvider.notifier).state =
      supplierId;
}

void clearCustomerLedgerDetailScope(WidgetRef ref) {
  ref.read(customerLedgerTimelineCustomerIdProvider.notifier).state = null;
  ref.read(customerLedgerTimelineTypeProvider.notifier).state = null;
  ref.read(customerLedgerTimelineOutstandingOnlyProvider.notifier).state =
      false;
  ref.read(customerLedgerTimelinePaymentHistoryProvider.notifier).state = true;
  ref.read(customerLedgerTimelineStartDateProvider.notifier).state = null;
  ref.read(customerLedgerTimelineEndDateProvider.notifier).state = null;
}

void clearSupplierLedgerDetailScope(WidgetRef ref) {
  ref.read(supplierLedgerTimelineSupplierIdProvider.notifier).state = null;
  ref.read(supplierLedgerTimelineTypeProvider.notifier).state = null;
  ref.read(supplierLedgerTimelineOutstandingOnlyProvider.notifier).state =
      false;
  ref.read(supplierLedgerTimelinePaymentHistoryProvider.notifier).state = true;
  ref.read(supplierLedgerTimelineStartDateProvider.notifier).state = null;
  ref.read(supplierLedgerTimelineEndDateProvider.notifier).state = null;
}

void refreshCustomerLedgerReports(WidgetRef ref) {
  ref.invalidate(customerLedgerSummaryProvider);
  ref.invalidate(customerLedgerTimelineProvider);
  ref.invalidate(cashLedgerRowsProvider);
}

void refreshSupplierLedgerReports(WidgetRef ref) {
  ref.invalidate(supplierLedgerSummaryProvider);
  ref.invalidate(supplierLedgerTimelineProvider);
  ref.invalidate(cashLedgerRowsProvider);
}
