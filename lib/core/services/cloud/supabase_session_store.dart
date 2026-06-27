import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

/// Persists the signed-in [SupabaseSession] in the existing `app_settings`
/// table (no schema migration). Tokens are stored locally on the shop's own
/// device, consistent with the app's soft-security model.
class SupabaseSessionStore {
  const SupabaseSessionStore({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static const String sessionKey = 'cloud.supabase.session';

  final AppDatabase _appDatabase;

  Future<SupabaseSession?> read() async {
    final raw = await _readSetting(sessionKey);
    return SupabaseSession.tryParse(raw);
  }

  Future<void> write(SupabaseSession session) async {
    await _writeSetting(sessionKey, session.encode());
  }

  Future<void> clear() async {
    await _appDatabase.database.delete(
      TableNames.appSettings,
      where: 'key = ?',
      whereArgs: <Object?>[sessionKey],
    );
  }

  Future<bool> isSignedIn() async => (await read()) != null;

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
