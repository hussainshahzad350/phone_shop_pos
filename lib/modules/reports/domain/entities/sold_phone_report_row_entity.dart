class SoldPhoneReportRowEntity {
  const SoldPhoneReportRowEntity({
    required this.invoiceNumber,
    required this.saleDate,
    required this.productName,
    required this.imei,
    required this.customerName,
    required this.salePrice,
    required this.costPrice,
  });

  final String invoiceNumber;
  final DateTime saleDate;
  final String productName;
  final String imei;
  final String customerName;
  final double salePrice;
  final double costPrice;

  double get profit => salePrice - costPrice;
}
