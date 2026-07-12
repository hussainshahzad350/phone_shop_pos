import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';

class ImeiManagementEntry {
  const ImeiManagementEntry({
    required this.stockId,
    required this.imei1,
    required this.stockStatus,
    required this.costPrice,
    required this.createdAt,
    this.imei2,
    this.purchaseDate,
    this.supplierId,
    this.supplierName,
  });

  final String stockId;
  final String imei1;
  final String? imei2;
  final SerializedStockStatus stockStatus;
  final double costPrice;
  final DateTime? purchaseDate;
  final DateTime createdAt;
  final String? supplierId;
  final String? supplierName;

  bool get isDeletable => stockStatus == SerializedStockStatus.inStock;
}
