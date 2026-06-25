import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

/// Persists the editable [ShopProfile] in the existing `app_settings`
/// key/value table. No schema migration is required.
class ShopProfileRepository {
  const ShopProfileRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static const String shopProfileKey = 'shop_profile';

  final AppDatabase _appDatabase;

  /// Loads the saved profile, falling back to [defaults] when nothing is
  /// persisted yet or the stored value is malformed.
  Future<ShopProfile> load(ShopProfile defaults) async {
    final raw = await _readSetting(shopProfileKey);
    return ShopProfile.tryParse(raw) ?? defaults;
  }

  Future<void> save(ShopProfile profile) async {
    await _writeSetting(shopProfileKey, profile.encode());
  }

  Future<String?> _readSetting(String key) async {
    final rows = await _appDatabase.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _writeSetting(String key, String value) async {
    await _appDatabase.database.insert(
      TableNames.appSettings,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
