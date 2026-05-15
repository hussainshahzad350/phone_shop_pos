class StockReportRowEntity {
  const StockReportRowEntity({
    required this.productName,
    required this.category,
    required this.availableQuantity,
    required this.minQuantity,
    required this.unitCost,
    required this.unitPrice,
    required this.location,
    required this.isLowStock,
  });

  final String productName;
  final String category;
  final int availableQuantity;
  final int minQuantity;
  final double unitCost;
  final double unitPrice;
  final String? location;
  final bool isLowStock;

  double get stockValue => unitCost * availableQuantity;
}
