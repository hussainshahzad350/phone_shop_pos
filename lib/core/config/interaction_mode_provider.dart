import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/interaction_mode.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

class InteractionModeNotifier extends AsyncNotifier<AppInteractionMode> {
  static const String _key = 'interaction_mode';

  @override
  Future<AppInteractionMode> build() async {
    return _load();
  }

  Future<AppInteractionMode> _load() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final rows = await db.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return AppInteractionMode.desktop;
    }
    final value = rows.first['value'] as String?;
    return AppInteractionMode.fromString(value);
  }

  Future<void> setMode(AppInteractionMode mode) async {
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

final interactionModeProvider =
    AsyncNotifierProvider<InteractionModeNotifier, AppInteractionMode>(
  InteractionModeNotifier.new,
);

/// True when the operator has enabled Touch mode in Settings. Defaults to
/// false while the persisted value is still loading so the desktop profile
/// (today's behavior) renders during startup.
final isTouchModeProvider = Provider<bool>((ref) {
  return ref.watch(interactionModeProvider
          .select((state) => state.valueOrNull)) ==
      AppInteractionMode.touch;
});
