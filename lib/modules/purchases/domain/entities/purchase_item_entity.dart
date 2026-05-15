class PurchaseItemEntity {
  const PurchaseItemEntity({
    required this.id,
    required this.purchaseId,
    required this.productModelId,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    required this.createdAt,
    required this.updatedAt,
    this.serializedStockId,
  });

  final String id;
  final String purchaseId;
  final String productModelId;
  final String? serializedStockId;
  final int quantity;
  final double unitCost;
  final double lineTotal;
  final DateTime createdAt;
  final DateTime updatedAt;
}
