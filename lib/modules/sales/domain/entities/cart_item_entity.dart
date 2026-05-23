class CartItemEntity {
  const CartItemEntity({
    required this.productModelId,
    required this.productName,
    required this.hasImei,
    required this.quantity,
    required this.unitPrice,
    this.serializedStockId,
    this.imei,
    this.imei2,
    this.serialNumber,
  });

  final String productModelId;
  final String productName;
  final bool hasImei;
  final int quantity;
  final double unitPrice;
  final String? serializedStockId;
  final String? imei;
  final String? imei2;
  final String? serialNumber;

  double get lineTotal => unitPrice * quantity;

  CartItemEntity copyWith({
    String? productModelId,
    String? productName,
    bool? hasImei,
    int? quantity,
    double? unitPrice,
    String? serializedStockId,
    String? imei,
    String? imei2,
    String? serialNumber,
    bool clearSerializedStockId = false,
    bool clearImei = false,
    bool clearImei2 = false,
    bool clearSerialNumber = false,
  }) {
    return CartItemEntity(
      productModelId: productModelId ?? this.productModelId,
      productName: productName ?? this.productName,
      hasImei: hasImei ?? this.hasImei,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      serializedStockId: clearSerializedStockId
          ? null
          : serializedStockId ?? this.serializedStockId,
      imei: clearImei ? null : imei ?? this.imei,
      imei2: clearImei2 ? null : imei2 ?? this.imei2,
      serialNumber:
          clearSerialNumber ? null : serialNumber ?? this.serialNumber,
    );
  }
}
