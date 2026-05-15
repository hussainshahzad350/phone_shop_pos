import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

abstract class BaseDbModel {
  const BaseDbModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toBaseMap() {
    return <String, Object?>{
      'id': id,
      'created_at': DateTimeHelpers.toSql(createdAt),
      'updated_at': DateTimeHelpers.toSql(updatedAt),
    };
  }
}
