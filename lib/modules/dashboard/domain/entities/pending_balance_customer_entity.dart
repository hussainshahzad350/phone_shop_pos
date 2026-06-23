class PendingBalanceCustomerEntity {
  const PendingBalanceCustomerEntity({
    required this.customerName,
    required this.invoiceNumber,
    required this.total,
    required this.paidAmount,
    required this.saleDate,
  });

  final String customerName;
  final String invoiceNumber;
  final double total;
  final double paidAmount;
  final DateTime saleDate;

  double get pendingAmount => (total - paidAmount).clamp(0.0, double.infinity);
}
