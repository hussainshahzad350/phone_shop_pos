enum SerializedStockStatus {
  inStock('in_stock'),
  sold('sold'),
  reserved('reserved'),
  returned('returned'),
  damaged('damaged');

  const SerializedStockStatus(this.value);

  final String value;

  static SerializedStockStatus fromValue(String value) {
    return SerializedStockStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SerializedStockStatus.inStock,
    );
  }
}

class SerializedStockEntity {
  const SerializedStockEntity({
    required this.id,
    required this.productModelId,
    required this.imei1,
    required this.stockStatus,
    required this.costPrice,
    required this.createdAt,
    required this.updatedAt,
    this.imei2,
    this.serialNumber,
    this.sellingPrice,
    this.supplierId,
    this.notes,
  });

  final String id;
  final String productModelId;
  final String imei1;
  final String? imei2;
  final String? serialNumber;
  final SerializedStockStatus stockStatus;
  final double costPrice;
  final double? sellingPrice;
  final String? supplierId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
