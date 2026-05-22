import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';

class ImeiEntry {
  const ImeiEntry({
    required this.imei1,
    required this.costPrice,
    this.imei2,
    this.serialNumber,
    this.sellingPrice,
    this.condition = SerializedStockCondition.newPhone,
    this.sellerName,
    this.sellerIdCard,
    this.sellerAddress,
    this.remainingWarranty,
    this.accessories,
    this.phoneConditionNotes,
  });

  final String imei1;
  final String? imei2;
  final String? serialNumber;
  final double costPrice;
  final double? sellingPrice;

  // Used-phone fields
  final SerializedStockCondition condition;
  final String? sellerName;
  final String? sellerIdCard;
  final String? sellerAddress;
  final String? remainingWarranty;
  final String? accessories;
  final String? phoneConditionNotes;

  ImeiEntry copyWith({
    String? imei1,
    String? imei2,
    String? serialNumber,
    double? costPrice,
    double? sellingPrice,
    SerializedStockCondition? condition,
    String? sellerName,
    String? sellerIdCard,
    String? sellerAddress,
    String? remainingWarranty,
    String? accessories,
    String? phoneConditionNotes,
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
      condition: condition ?? this.condition,
      sellerName: sellerName ?? this.sellerName,
      sellerIdCard: sellerIdCard ?? this.sellerIdCard,
      sellerAddress: sellerAddress ?? this.sellerAddress,
      remainingWarranty: remainingWarranty ?? this.remainingWarranty,
      accessories: accessories ?? this.accessories,
      phoneConditionNotes: phoneConditionNotes ?? this.phoneConditionNotes,
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
