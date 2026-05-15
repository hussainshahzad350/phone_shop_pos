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
    required this.costPrice,
    this.serializedStockId,
  });

  final String saleId;
  final String productModelId;
  final String? serializedStockId;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  /// Historical cost price snapshot captured at the moment of sale.
  /// Used for profit calculations so that later stock-cost edits do not
  /// retroactively change previously recorded profits.
  final double costPrice;

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
      'cost_price': costPrice,
    };
  }
}
