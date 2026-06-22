import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/config/navigation_mode.dart';

class NavigationModeNotifier extends AsyncNotifier<AppNavigationMode> {
  static const String _key = 'navigation_mode';

  @override
  Future<AppNavigationMode> build() async {
    return _load();
  }

  Future<AppNavigationMode> _load() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final rows = await db.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return AppNavigationMode.sidebar;
    }
    final value = rows.first['value'] as String?;
    return AppNavigationMode.fromString(value);
  }

  Future<void> setMode(AppNavigationMode mode) async {
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

final navigationModeProvider =
    AsyncNotifierProvider<NavigationModeNotifier, AppNavigationMode>(
  NavigationModeNotifier.new,
);
