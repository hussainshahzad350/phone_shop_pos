import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
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

  factory SaleItemModel.fromMap(Map<String, Object?> map) {
    return SaleItemModel(
      id: map['id'] as String,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
      saleId: map['sale_id'] as String,
      productModelId: map['product_model_id'] as String,
      serializedStockId: map['serialized_stock_id'] as String?,
      quantity: _asInt(map['quantity']),
      unitPrice: _asDouble(map['unit_price']),
      discount: _asDouble(map['discount']),
      lineTotal: _asDouble(map['line_total']),
      costPrice: _asDouble(map['cost_price']),
    );
  }

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

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
