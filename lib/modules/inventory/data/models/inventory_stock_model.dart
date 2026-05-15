import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class InventoryStockModel extends BaseDbModel {
  const InventoryStockModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.productModelId,
    required this.quantity,
    required this.minQuantity,
    required this.unitCost,
    required this.unitPrice,
    this.maxQuantity,
    this.location,
  });

  final String productModelId;
  final int quantity;
  final int minQuantity;
  final int? maxQuantity;
  final double unitCost;
  final double unitPrice;
  final String? location;

  factory InventoryStockModel.fromMap(Map<String, Object?> map) {
    return InventoryStockModel(
      id: map['id'] as String,
      productModelId: map['product_model_id'] as String,
      quantity: map['quantity'] as int,
      minQuantity: map['min_quantity'] as int,
      maxQuantity: map['max_quantity'] as int?,
      unitCost: (map['unit_cost'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      location: map['location'] as String?,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'product_model_id': productModelId,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
      'unit_cost': unitCost,
      'unit_price': unitPrice,
      'location': location,
    };
  }
}
