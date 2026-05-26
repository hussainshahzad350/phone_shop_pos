import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

void main() {
  late Directory rootDirectory;
  late AppDatabase appDatabase;
  late LocalPinAuthService authService;
  late DateTime now;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_local_pin_controller_',
    );

    appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );

    await appDatabase.initialize();
    authService = LocalPinAuthService(appDatabase: appDatabase);
    now = DateTime.utc(2026, 5, 25, 18);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  test('login lockout persists across controller instances', () async {
    await authService.configurePin('1234');

    final controller = LocalPinAuthController(
      authService,
      nowProvider: () => now,
    );
    await _settle();

    for (var attempt = 0; attempt < 5; attempt++) {
      final success = await controller.loginWithPin('9999');
      expect(success, isFalse);
    }

    expect(controller.state.lockedUntil, isNotNull);
    expect(controller.state.failedAttempts, 5);

    final restartedController = LocalPinAuthController(
      authService,
      nowProvider: () => now,
    );
    await _settle();

    expect(restartedController.state.lockedUntil, isNotNull);
    expect(restartedController.state.failedAttempts, 5);

    final blocked = await restartedController.loginWithPin('1234');
    expect(blocked, isFalse);
    expect(restartedController.state.errorMessage, contains('Try again in'));
  });

  test('expired persisted lockout is cleared during initialization', () async {
    await authService.configurePin('1234');
    await authService.persistLockoutState(
      failedAttempts: 5,
      lockedUntil: now.subtract(const Duration(seconds: 5)),
    );

    final controller = LocalPinAuthController(
      authService,
      nowProvider: () => now,
    );
    await _settle();

    expect(controller.state.lockedUntil, isNull);
    expect(controller.state.failedAttempts, 0);

    final persisted = await authService.getLockoutState();
    expect(persisted.failedAttempts, 0);
    expect(persisted.lockedUntil, isNull);
  });

  test('expired lockout while app is open resets attempts before next try', () async {
    await authService.configurePin('1234');

    final controller = LocalPinAuthController(
      authService,
      nowProvider: () => now,
    );
    await _settle();

    for (var attempt = 0; attempt < 5; attempt++) {
      final success = await controller.loginWithPin('9999');
      expect(success, isFalse);
    }
    expect(controller.state.failedAttempts, 5);
    final lockedUntil = controller.state.lockedUntil;
    expect(lockedUntil, isNotNull);

    now = lockedUntil!.add(const Duration(seconds: 1));
    final afterExpiryWrongPin = await controller.loginWithPin('9999');
    expect(afterExpiryWrongPin, isFalse);
    expect(controller.state.failedAttempts, 1);
    expect(controller.state.lockedUntil, isNull);
    expect(
      controller.state.errorMessage,
      contains('4 attempts left'),
    );

    final persisted = await authService.getLockoutState();
    expect(persisted.failedAttempts, 1);
    expect(persisted.lockedUntil, isNull);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
