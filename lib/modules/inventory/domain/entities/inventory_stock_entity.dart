class InventoryStockEntity {
  const InventoryStockEntity({
    required this.id,
    required this.productModelId,
    required this.quantity,
    required this.minQuantity,
    required this.unitCost,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
    this.maxQuantity,
    this.location,
  });

  final String id;
  final String productModelId;
  final int quantity;
  final int minQuantity;
  final int? maxQuantity;
  final double unitCost;
  final double unitPrice;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= minQuantity;
}
