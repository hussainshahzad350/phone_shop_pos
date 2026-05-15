class LowStockReportRowEntity {
  const LowStockReportRowEntity({
    required this.productName,
    required this.quantity,
    required this.minQuantity,
    this.location,
  });

  final String productName;
  final int quantity;
  final int minQuantity;
  final String? location;
}
