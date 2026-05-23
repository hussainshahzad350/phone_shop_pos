import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

void main() {
  late Directory rootDirectory;
  late AppDatabase appDatabase;
  late LocalPinAuthService authService;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_local_pin_auth_',
    );

    final localDatabaseService = SqliteFfiDatabaseService(
      rootDirectory: rootDirectory.path,
    );

    appDatabase = AppDatabase(
      localDatabaseService: localDatabaseService,
      migrationService: const MigrationService(),
    );

    await appDatabase.initialize();
    authService = LocalPinAuthService(appDatabase: appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  test('regenerateRecoveryCode returns null for wrong current PIN', () async {
    await authService.configurePin('1234');

    final regenerated = await authService.regenerateRecoveryCode(
      currentPin: '9999',
    );

    expect(regenerated, isNull);
  });

  test('regenerateRecoveryCode rotates recovery code and keeps auth flow valid',
      () async {
    final originalRecovery = await authService.configurePin('1234');

    final regenerated = await authService.regenerateRecoveryCode(
      currentPin: '1234',
    );

    expect(regenerated, isNotNull);
    expect(regenerated, isNot(equals(originalRecovery)));

    final resetWithOldCode = await authService.resetPinWithRecoveryCode(
      recoveryCode: originalRecovery,
      newPin: '5555',
    );
    expect(resetWithOldCode, isFalse);

    final resetWithNewCode = await authService.resetPinWithRecoveryCode(
      recoveryCode: regenerated!,
      newPin: '5555',
    );
    expect(resetWithNewCode, isTrue);

    final newPinWorks = await authService.verifyPin('5555');
    expect(newPinWorks, isTrue);
  });
}
