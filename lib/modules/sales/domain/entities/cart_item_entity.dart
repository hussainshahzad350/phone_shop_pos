class CartItemEntity {
  const CartItemEntity({
    required this.productModelId,
    required this.productName,
    required this.hasImei,
    required this.quantity,
    required this.unitPrice,
    this.serializedStockId,
    this.imei,
  });

  final String productModelId;
  final String productName;
  final bool hasImei;
  final int quantity;
  final double unitPrice;
  final String? serializedStockId;
  final String? imei;

  double get lineTotal => unitPrice * quantity;

  CartItemEntity copyWith({
    String? productModelId,
    String? productName,
    bool? hasImei,
    int? quantity,
    double? unitPrice,
    String? serializedStockId,
    String? imei,
    bool clearSerializedStockId = false,
    bool clearImei = false,
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
    );
  }
}
