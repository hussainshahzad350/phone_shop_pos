import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class SerializedStockModel extends BaseDbModel {
  const SerializedStockModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.productModelId,
    required this.imei1,
    required this.stockStatus,
    required this.costPrice,
    this.imei2,
    this.serialNumber,
    this.sellingPrice,
    this.supplierId,
    this.notes,
    this.condition = SerializedStockCondition.newPhone,
    this.sellerName,
    this.sellerIdCard,
    this.sellerAddress,
    this.remainingWarranty,
    this.accessories,
    this.phoneConditionNotes,
  });

  final String productModelId;
  final String imei1;
  final String? imei2;
  final String? serialNumber;
  final SerializedStockStatus stockStatus;
  final double costPrice;
  final double? sellingPrice;
  final String? supplierId;
  final String? notes;

  // Used-phone fields
  final SerializedStockCondition condition;
  final String? sellerName;
  final String? sellerIdCard;
  final String? sellerAddress;
  final String? remainingWarranty;
  final String? accessories;
  final String? phoneConditionNotes;

  factory SerializedStockModel.fromMap(Map<String, Object?> map) {
    return SerializedStockModel(
      id: map['id'] as String,
      productModelId: map['product_model_id'] as String,
      imei1: map['imei1'] as String,
      imei2: map['imei2'] as String?,
      serialNumber: map['serial_number'] as String?,
      stockStatus: SerializedStockStatus.fromValue(map['stock_status'] as String),
      costPrice: (map['cost_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num?)?.toDouble(),
      supplierId: map['supplier_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
      condition: SerializedStockCondition.fromValue(map['condition'] as String?),
      sellerName: map['seller_name'] as String?,
      sellerIdCard: map['seller_id_card'] as String?,
      sellerAddress: map['seller_address'] as String?,
      remainingWarranty: map['remaining_warranty'] as String?,
      accessories: map['accessories'] as String?,
      phoneConditionNotes: map['phone_condition_notes'] as String?,
    );
  }

  factory SerializedStockModel.fromEntity(SerializedStockEntity entity) {
    return SerializedStockModel(
      id: entity.id,
      productModelId: entity.productModelId,
      imei1: entity.imei1,
      imei2: entity.imei2,
      serialNumber: entity.serialNumber,
      stockStatus: entity.stockStatus,
      costPrice: entity.costPrice,
      sellingPrice: entity.sellingPrice,
      supplierId: entity.supplierId,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      condition: entity.condition,
      sellerName: entity.sellerName,
      sellerIdCard: entity.sellerIdCard,
      sellerAddress: entity.sellerAddress,
      remainingWarranty: entity.remainingWarranty,
      accessories: entity.accessories,
      phoneConditionNotes: entity.phoneConditionNotes,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'product_model_id': productModelId,
      'imei1': imei1,
      'imei2': imei2,
      'serial_number': serialNumber,
      'stock_status': stockStatus.value,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'supplier_id': supplierId,
      'notes': notes,
      'condition': condition.value,
      'seller_name': sellerName,
      'seller_id_card': sellerIdCard,
      'seller_address': sellerAddress,
      'remaining_warranty': remainingWarranty,
      'accessories': accessories,
      'phone_condition_notes': phoneConditionNotes,
    };
  }

  SerializedStockEntity toEntity() {
    return SerializedStockEntity(
      id: id,
      productModelId: productModelId,
      imei1: imei1,
      imei2: imei2,
      serialNumber: serialNumber,
      stockStatus: stockStatus,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      supplierId: supplierId,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      condition: condition,
      sellerName: sellerName,
      sellerIdCard: sellerIdCard,
      sellerAddress: sellerAddress,
      remainingWarranty: remainingWarranty,
      accessories: accessories,
      phoneConditionNotes: phoneConditionNotes,
    );
  }
}
