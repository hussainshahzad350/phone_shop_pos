class ImeiEntry {
  const ImeiEntry({
    required this.imei1,
    required this.costPrice,
    this.imei2,
    this.serialNumber,
    this.sellingPrice,
  });

  final String imei1;
  final String? imei2;
  final String? serialNumber;
  final double costPrice;
  final double? sellingPrice;

  ImeiEntry copyWith({
    String? imei1,
    String? imei2,
    String? serialNumber,
    double? costPrice,
    double? sellingPrice,
    bool clearImei2 = false,
    bool clearSerialNumber = false,
    bool clearSellingPrice = false,
  }) {
    return ImeiEntry(
      imei1: imei1 ?? this.imei1,
      imei2: clearImei2 ? null : imei2 ?? this.imei2,
      serialNumber: clearSerialNumber ? null : serialNumber ?? this.serialNumber,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: clearSellingPrice ? null : sellingPrice ?? this.sellingPrice,
    );
  }
}

class PurchaseFormItem {
  const PurchaseFormItem({
    required this.productModelId,
    required this.productName,
    required this.hasImei,
    this.imeiEntries = const <ImeiEntry>[],
    this.quantity = 1,
    this.unitCost = 0,
    this.supplierId,
  });

  final String productModelId;
  final String productName;
  final bool hasImei;
  final List<ImeiEntry> imeiEntries;
  final int quantity;
  final double unitCost;
  final String? supplierId;

  double get lineTotal => hasImei
      ? imeiEntries.fold(0, (sum, e) => sum + e.costPrice)
      : quantity * unitCost;

  int get effectiveQuantity => hasImei ? imeiEntries.length : quantity;

  PurchaseFormItem copyWith({
    String? productModelId,
    String? productName,
    bool? hasImei,
    List<ImeiEntry>? imeiEntries,
    int? quantity,
    double? unitCost,
    String? supplierId,
    bool clearSupplierId = false,
  }) {
    return PurchaseFormItem(
      productModelId: productModelId ?? this.productModelId,
      productName: productName ?? this.productName,
      hasImei: hasImei ?? this.hasImei,
      imeiEntries: imeiEntries ?? this.imeiEntries,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      supplierId: clearSupplierId ? null : supplierId ?? this.supplierId,
    );
  }
}
