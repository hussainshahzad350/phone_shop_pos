import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class SupplierModel extends BaseDbModel {
  const SupplierModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
  });

  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;

  factory SupplierModel.fromMap(Map<String, Object?> map) {
    return SupplierModel(
      id: map['id'] as String,
      name: map['name'] as String,
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
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
    };
  }
}
