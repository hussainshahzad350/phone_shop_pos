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
    this.purchaseDate,
    this.supplierName,
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

  /// Inventory add date / supplier of the specific unit added to the cart —
  /// captured at add-to-cart time (a deliberate snapshot, matching the
  /// existing cost_price-at-sale-time precedent), not re-queried live.
  final DateTime? purchaseDate;
  final String? supplierName;

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
    DateTime? purchaseDate,
    String? supplierName,
    bool clearSerializedStockId = false,
    bool clearImei = false,
    bool clearImei2 = false,
    bool clearSerialNumber = false,
    bool clearPurchaseDate = false,
    bool clearSupplierName = false,
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
      purchaseDate:
          clearPurchaseDate ? null : purchaseDate ?? this.purchaseDate,
      supplierName:
          clearSupplierName ? null : supplierName ?? this.supplierName,
    );
  }
}
