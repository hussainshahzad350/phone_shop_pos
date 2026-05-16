import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class BrandModel extends BaseDbModel {
  const BrandModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.isActive,
  });

  final String name;
  final bool isActive;

  factory BrandModel.fromMap(Map<String, Object?> map) {
    return BrandModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as num) == 1,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
    );
  }

  factory BrandModel.fromEntity(BrandEntity entity) {
    return BrandModel(
      id: entity.id,
      name: entity.name,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  BrandEntity toEntity() {
    return BrandEntity(
      id: id,
      name: name,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
