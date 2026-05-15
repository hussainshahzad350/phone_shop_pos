import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class SaleItemModel extends BaseDbModel {
  const SaleItemModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.saleId,
    required this.productModelId,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    this.serializedStockId,
  });

  final String saleId;
  final String productModelId;
  final String? serializedStockId;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'sale_id': saleId,
      'product_model_id': productModelId,
      'serialized_stock_id': serializedStockId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'line_total': lineTotal,
    };
  }
}
