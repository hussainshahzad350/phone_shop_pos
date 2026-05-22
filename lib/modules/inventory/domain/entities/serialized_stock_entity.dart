enum SerializedStockCondition {
  newPhone('new'),
  used('used');

  const SerializedStockCondition(this.value);

  final String value;

  static SerializedStockCondition fromValue(String? value) {
    return SerializedStockCondition.values.firstWhere(
      (c) => c.value == value,
      orElse: () => SerializedStockCondition.newPhone,
    );
  }
}

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
    this.condition = SerializedStockCondition.newPhone,
    this.sellerName,
    this.sellerIdCard,
    this.sellerAddress,
    this.remainingWarranty,
    this.accessories,
    this.phoneConditionNotes,
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

  // Used-phone fields
  final SerializedStockCondition condition;
  final String? sellerName;
  final String? sellerIdCard;
  final String? sellerAddress;
  final String? remainingWarranty;
  final String? accessories;
  final String? phoneConditionNotes;
}
