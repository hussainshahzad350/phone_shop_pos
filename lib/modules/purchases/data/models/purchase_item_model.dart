import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_item_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class PurchaseItemModel extends BaseDbModel {
  const PurchaseItemModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.purchaseId,
    required this.productModelId,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    this.serializedStockId,
  });

  final String purchaseId;
  final String productModelId;
  final String? serializedStockId;
  final int quantity;
  final double unitCost;
  final double lineTotal;

  factory PurchaseItemModel.fromMap(Map<String, Object?> map) {
    return PurchaseItemModel(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      productModelId: map['product_model_id'] as String,
      serializedStockId: map['serialized_stock_id'] as String?,
      quantity: map['quantity'] as int,
      unitCost: (map['unit_cost'] as num).toDouble(),
      lineTotal: (map['line_total'] as num).toDouble(),
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
    );
  }

  factory PurchaseItemModel.fromEntity(PurchaseItemEntity entity) {
    return PurchaseItemModel(
      id: entity.id,
      purchaseId: entity.purchaseId,
      productModelId: entity.productModelId,
      serializedStockId: entity.serializedStockId,
      quantity: entity.quantity,
      unitCost: entity.unitCost,
      lineTotal: entity.lineTotal,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'purchase_id': purchaseId,
      'product_model_id': productModelId,
      'serialized_stock_id': serializedStockId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'line_total': lineTotal,
    };
  }

  PurchaseItemEntity toEntity() {
    return PurchaseItemEntity(
      id: id,
      purchaseId: purchaseId,
      productModelId: productModelId,
      serializedStockId: serializedStockId,
      quantity: quantity,
      unitCost: unitCost,
      lineTotal: lineTotal,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
