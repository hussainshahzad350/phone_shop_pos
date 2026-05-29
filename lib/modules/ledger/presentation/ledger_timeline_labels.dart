import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';

String normalizeCustomerLedgerName(String rawName) {
  final normalized = rawName.trim();
  if (normalized.isEmpty ||
      normalized.toLowerCase() == 'walk-in customer' ||
      normalized.toLowerCase() == 'unknown customer') {
    return 'Unidentified Customer';
  }
  return normalized;
}

String normalizeSupplierLedgerName(String rawName) {
  final normalized = rawName.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'unknown supplier') {
    return 'Unidentified Supplier';
  }
  return normalized;
}

String customerLedgerBalanceSubtitle(PartySummaryCardEntity summary) {
  final net = summary.netBalance;
  if (net > 0.009) {
    return 'Outstanding Receivable: ${FormattingHelpers.currencyPkr(net)}';
  }
  if (net < -0.009) {
    return 'Shop Owes Customer: ${FormattingHelpers.currencyPkr(net.abs())}';
  }
  return 'Settled — no outstanding balance';
}

String supplierLedgerBalanceSubtitle(PartySummaryCardEntity summary) {
  final net = summary.netBalance;
  if (net > 0.009) {
    return 'Payable: ${FormattingHelpers.currencyPkr(net)}';
  }
  if (net < -0.009) {
    return 'Supplier Credit: ${FormattingHelpers.currencyPkr(net.abs())}';
  }
  return 'Settled — no outstanding balance';
}

String humanizeCustomerLedgerType(String ledgerType) {
  switch (ledgerType.trim().toLowerCase()) {
    case 'sale':
      return 'Phone Sale Due';
    case 'sale_payment':
      return 'Sale Payment';
    case 'sale_return':
      return 'Sale Refund';
    case 'repair_due':
      return 'Repair Due';
    case 'repair_payment':
      return 'Repair Payment';
    case 'used_phone_buy':
      return 'Used Phone Purchase';
    case 'used_phone_payment':
      return 'Used Phone Payment';
    case 'advance_receive':
      return 'Advance Received';
    case 'advance_use':
      return 'Advance Used';
    case 'advance_adjust':
      return 'Advance Adjustment';
    case 'manual_settlement':
      return 'Credit Received';
    case 'reversal':
      return 'Reversal';
    default:
      return ledgerType.replaceAll('_', ' ');
  }
}

String humanizeSupplierLedgerType(String ledgerType) {
  switch (ledgerType.trim().toLowerCase()) {
    case 'purchase':
      return 'Purchase Due';
    case 'purchase_payment':
      return 'Purchase Payment';
    case 'purchase_return':
      return 'Purchase Return';
    case 'advance_receive':
      return 'Advance Paid';
    case 'advance_adjust':
      return 'Advance Adjustment';
    case 'manual_settlement':
      return 'Credit Paid';
    case 'reversal':
      return 'Reversal';
    default:
      return ledgerType.replaceAll('_', ' ');
  }
}

bool customerLedgerRowMatchesCategory(String ledgerType, String? category) {
  if (category == null || category == 'all') {
    return true;
  }
  final type = ledgerType.trim().toLowerCase();
  switch (category) {
    case 'sales':
      return type == 'sale' || type == 'sale_payment' || type == 'sale_return';
    case 'repairs':
      return type == 'repair_due' || type == 'repair_payment';
    case 'payments':
      return type == 'sale_payment' ||
          type == 'repair_payment' ||
          type == 'used_phone_payment' ||
          type == 'manual_settlement';
    case 'refunds':
      return type == 'sale_return';
    case 'used_phones':
      return type == 'used_phone_buy' || type == 'used_phone_payment';
    case 'reversals':
      return type == 'reversal';
    default:
      return true;
  }
}

bool supplierLedgerRowMatchesCategory(String ledgerType, String? category) {
  if (category == null || category == 'all') {
    return true;
  }
  final type = ledgerType.trim().toLowerCase();
  switch (category) {
    case 'purchases':
      return type == 'purchase' ||
          type == 'purchase_payment' ||
          type == 'purchase_return';
    case 'payments':
      return type == 'purchase_payment' || type == 'manual_settlement';
    case 'returns':
      return type == 'purchase_return';
    case 'advances':
      return type == 'advance_receive' || type == 'advance_adjust';
    case 'reversals':
      return type == 'reversal';
    default:
      return true;
  }
}

List<LedgerTimelineRowEntity> newestFirstTimeline(
  List<LedgerTimelineRowEntity> rows,
) {
  final sorted = List<LedgerTimelineRowEntity>.of(rows)
    ..sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      if (byDate != 0) {
        return byDate;
      }
      return b.id.compareTo(a.id);
    });
  return sorted;
}

bool ledgerRowMatchesSearch(LedgerTimelineRowEntity row, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return row.transactionId.toLowerCase().contains(normalized) ||
      row.id.toLowerCase().contains(normalized) ||
      (row.note ?? '').toLowerCase().contains(normalized);
}
