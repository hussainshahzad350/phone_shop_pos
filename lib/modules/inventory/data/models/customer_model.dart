import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class CustomerModel extends BaseDbModel {
  const CustomerModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    this.phone,
    this.email,
    this.address,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? address;

  factory CustomerModel.fromMap(Map<String, Object?> map) {
    return CustomerModel(
      id: map['id'] as String,
      name: map['name'] as String,
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
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}
