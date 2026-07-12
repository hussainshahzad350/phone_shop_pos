class ModelImeiStockEntity {
  ModelImeiStockEntity({
    required this.modelId,
    required this.modelName,
    required this.brandName,
    required this.quantity,
    required this.imeis,
  });

  final String modelId;
  final String modelName;
  final String brandName;
  int quantity;
  final List<ImeiStockItemEntity> imeis;
}

class ImeiStockItemEntity {
  const ImeiStockItemEntity({
    required this.serializedStockId,
    required this.imei,
    required this.imei2,
    required this.serialNumber,
    required this.costPrice,
    required this.salePrice,
    required this.stockStatus,
    this.purchaseDate,
    this.supplierName,
  });

  final String serializedStockId;
  final String imei;
  final String? imei2;
  final String? serialNumber;
  final double costPrice;
  final double salePrice;
  final String stockStatus;
  final DateTime? purchaseDate;
  final String? supplierName;
}