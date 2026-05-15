class DashboardRecentSaleEntity {
  const DashboardRecentSaleEntity({
    required this.invoiceNumber,
    required this.saleDate,
    required this.customerName,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
  });

  final String invoiceNumber;
  final DateTime saleDate;
  final String customerName;
  final double total;
  final double paidAmount;
  final String? paymentMethod;

  double get pendingAmount => (total - paidAmount).clamp(0, double.infinity);
}
