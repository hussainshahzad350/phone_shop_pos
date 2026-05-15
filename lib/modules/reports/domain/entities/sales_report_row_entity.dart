class SalesReportRowEntity {
  const SalesReportRowEntity({
    required this.invoiceNumber,
    required this.saleDate,
    required this.customerName,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
    required this.status,
  });

  final String invoiceNumber;
  final DateTime saleDate;
  final String customerName;
  final double total;
  final double paidAmount;
  final String? paymentMethod;
  final String status;

  double get balance => (total - paidAmount).clamp(0, double.infinity);
}
