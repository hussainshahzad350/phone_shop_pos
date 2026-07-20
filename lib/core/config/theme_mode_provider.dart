import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/app_theme_mode.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

/// Loads and persists the user's appearance choice in the `app_settings`
/// key/value table. Mirrors the navigation-mode persistence pattern so no
/// schema change is required (additive rows only).
class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  static const String _key = 'theme_mode';

  @override
  Future<AppThemeMode> build() async {
    return _load();
  }

  Future<AppThemeMode> _load() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final rows = await db.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return AppThemeMode.system;
    }
    final value = rows.first['value'] as String?;
    return AppThemeMode.fromString(value);
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = const AsyncLoading();
    final db = await ref.read(appDatabaseProvider.future);
    await db.database.insert(
      TableNames.appSettings,
      <String, Object?>{
        'key': _key,
        'value': mode.name,
        'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    state = AsyncData(mode);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
