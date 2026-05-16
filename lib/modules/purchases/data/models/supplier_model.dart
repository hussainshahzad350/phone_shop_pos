import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class SupplierModel extends BaseDbModel {
  const SupplierModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.isActive,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;

  factory SupplierModel.fromMap(Map<String, Object?> map) {
    return SupplierModel(
      id: map['id'] as String,
      name: map['name'] as String,
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as num?) == 1,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
    );
  }

  factory SupplierModel.fromEntity(SupplierEntity entity) {
    return SupplierModel(
      id: entity.id,
      name: entity.name,
      contactPerson: entity.contactPerson,
      phone: entity.phone,
      email: entity.email,
      address: entity.address,
      notes: entity.notes,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
    };
  }

  SupplierEntity toEntity() {
    return SupplierEntity(
      id: id,
      name: name,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
