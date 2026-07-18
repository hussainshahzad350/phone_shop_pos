/// Kind of event shown in the dashboard "Recent Transactions" feed.
enum DashboardTransactionType {
  sale,
  purchase,
  repair,
  customerPayment,
}

/// A single row of the mixed "Recent Transactions" feed: sales, purchases,
/// repair jobs and customer (udhaar) payments merged into one timeline.
class DashboardTransactionEntity {
  const DashboardTransactionEntity({
    required this.type,
    required this.title,
    required this.reference,
    required this.date,
    required this.amount,
    this.saleId,
  });

  final DashboardTransactionType type;

  /// Display title, e.g. "Sale — Bilal Ahmed" or "Repair — iPhone 11".
  final String title;

  /// Document reference, e.g. invoice number or ledger label.
  final String reference;

  final DateTime date;

  /// Positive amounts are inflows (sales, payments); purchases are outflows
  /// and are displayed with a minus sign.
  final double amount;

  /// Present only for sales rows so the invoice dialog can be opened.
  final String? saleId;

  bool get isOutflow => type == DashboardTransactionType.purchase;
}
