import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';

enum StockRowType { serialized, quantity }

class StockRowEntity {
  const StockRowEntity({
    required this.type,
    required this.productModelId,
    required this.productName,
    this.brand,
    this.category,
    this.sku,
    this.serializedStockId,
    this.imei1,
    this.imei2,
    this.serialNumber,
    this.serializedStatus,
    this.costPrice,
    this.sellingPrice,
    this.inventoryStockId,
    this.quantity,
    this.minQuantity,
    this.unitCost,
    this.unitPrice,
    this.location,
  });

  final StockRowType type;
  final String productModelId;
  final String productName;
  final String? brand;
  final String? category;
  final String? sku;

  final String? serializedStockId;
  final String? imei1;
  final String? imei2;
  final String? serialNumber;
  final SerializedStockStatus? serializedStatus;
  final double? costPrice;
  final double? sellingPrice;

  final String? inventoryStockId;
  final int? quantity;
  final int? minQuantity;
  final double? unitCost;
  final double? unitPrice;
  final String? location;

  bool get isLowStock =>
      type == StockRowType.quantity &&
      quantity != null &&
      minQuantity != null &&
      quantity! <= minQuantity!;
}
