import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';

void main() {
  test('appDatabaseProvider rebuilds with a fresh AppDatabase after restore epoch bump', () async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_recovery_provider_',
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
    addTearDown(() async {
      container.dispose();
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    final firstAppDatabase = await container.read(appDatabaseProvider.future);
    await firstAppDatabase.database.rawQuery('SELECT 1;');

    container.read(databaseRecoveryEpochProvider.notifier).state++;

    final secondAppDatabase = await container.read(appDatabaseProvider.future);
    expect(identical(firstAppDatabase, secondAppDatabase), isFalse);
    expect(() => firstAppDatabase.database, throwsStateError);
    await secondAppDatabase.database.rawQuery('SELECT 1;');
  });
}
