import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/interaction_mode.dart';
import 'package:phone_shop_pos/core/config/interaction_mode_provider.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

void main() {
  group('AppInteractionMode', () {
    test('fromString round-trips both modes and defaults to desktop', () {
      expect(
        AppInteractionMode.fromString(AppInteractionMode.touch.name),
        AppInteractionMode.touch,
      );
      expect(
        AppInteractionMode.fromString(AppInteractionMode.desktop.name),
        AppInteractionMode.desktop,
      );
      expect(
        AppInteractionMode.fromString('unknown_value'),
        AppInteractionMode.desktop,
      );
      expect(AppInteractionMode.fromString(null), AppInteractionMode.desktop);
    });
  });

  group('interactionModeProvider', () {
    test('defaults to desktop when no setting is persisted', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      final mode = await context.container.read(
        interactionModeProvider.future,
      );

      expect(mode, AppInteractionMode.desktop);
      expect(context.container.read(isTouchModeProvider), isFalse);
    });

    test('setMode persists touch and updates isTouchModeProvider', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      await context.container.read(interactionModeProvider.future);
      await context.container
          .read(interactionModeProvider.notifier)
          .setMode(AppInteractionMode.touch);

      expect(context.container.read(isTouchModeProvider), isTrue);

      final appDatabase =
          await context.container.read(appDatabaseProvider.future);
      final rows = await appDatabase.database.query(
        TableNames.appSettings,
        columns: <String>['value'],
        where: 'key = ?',
        whereArgs: <Object?>['interaction_mode'],
        limit: 1,
      );
      expect(rows, hasLength(1));
      expect(rows.first['value'], AppInteractionMode.touch.name);
    });

    test('loads a previously persisted touch mode', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase =
          await context.container.read(appDatabaseProvider.future);

      await appDatabase.database.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': 'interaction_mode',
          'value': AppInteractionMode.touch.name,
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final mode = await context.container.read(
        interactionModeProvider.future,
      );

      expect(mode, AppInteractionMode.touch);
      expect(context.container.read(isTouchModeProvider), isTrue);
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_interaction_mode_',
  );
  final container = ProviderContainer(
    overrides: <Override>[
      localDatabaseServiceProvider.overrideWith((ref) async {
        final service = SqliteFfiDatabaseService(
          rootDirectory: rootDirectory.path,
        );
        await service.initialize();
        return service;
      }),
    ],
  );
  return _ProviderTestContext(
    container: container,
    rootDirectory: rootDirectory,
  );
}

class _ProviderTestContext {
  const _ProviderTestContext({
    required this.container,
    required this.rootDirectory,
  });

  final ProviderContainer container;
  final Directory rootDirectory;

  Future<void> dispose() async {
    try {
      final appDatabase = await container.read(appDatabaseProvider.future);
      await appDatabase.close();
    } catch (_) {
      // Tests that fail before database initialization still need cleanup.
    }
    container.dispose();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }
}
