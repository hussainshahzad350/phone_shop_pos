import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_stock_entity.dart';
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

  factory InventoryStockModel.fromEntity(InventoryStockEntity entity) {
    return InventoryStockModel(
      id: entity.id,
      productModelId: entity.productModelId,
      quantity: entity.quantity,
      minQuantity: entity.minQuantity,
      maxQuantity: entity.maxQuantity,
      unitCost: entity.unitCost,
      unitPrice: entity.unitPrice,
      location: entity.location,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
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

  InventoryStockEntity toEntity() {
    return InventoryStockEntity(
      id: id,
      productModelId: productModelId,
      quantity: quantity,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
      unitCost: unitCost,
      unitPrice: unitPrice,
      location: location,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
