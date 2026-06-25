import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

void main() {
  group('LocalPinAuthService recovery email', () {
    test('stores and trims the recovery email', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final service = await context.service();

      expect(await service.getRecoveryEmail(), isNull);
      expect(await service.hasRecoveryEmail(), isFalse);

      await service.setRecoveryEmail('  owner@shop.com  ');

      expect(await service.getRecoveryEmail(), 'owner@shop.com');
      expect(await service.hasRecoveryEmail(), isTrue);

      await service.clearRecoveryEmail();
      expect(await service.getRecoveryEmail(), isNull);
    });

    test('resetPinAfterEmailVerification rewrites PIN and recovery code',
        () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final service = await context.service();

      final originalRecoveryCode = await service.configurePin('1234');
      expect(await service.verifyPin('1234'), isTrue);

      final newRecoveryCode =
          await service.resetPinAfterEmailVerification('5678');

      expect(newRecoveryCode, isNotEmpty);
      expect(await service.verifyPin('5678'), isTrue);
      expect(await service.verifyPin('1234'), isFalse);

      // The old recovery code must no longer work; the freshly issued one must.
      expect(
        await service.resetPinWithRecoveryCode(
          recoveryCode: originalRecoveryCode,
          newPin: '4321',
        ),
        isFalse,
      );
      expect(
        await service.resetPinWithRecoveryCode(
          recoveryCode: newRecoveryCode,
          newPin: '4321',
        ),
        isTrue,
      );
    });
  });

  group('LocalPinAuthController setup with email', () {
    test('stores a valid recovery email on setup', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final service = await context.service();
      final controller = LocalPinAuthController(service);
      addTearDown(controller.dispose);
      // Let the controller's async _initialize finish so it does not race with
      // teardown disposal.
      while (!controller.debugState.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final code = await controller.setupPin(
        pin: '1234',
        confirmPin: '1234',
        recoveryEmail: '  owner@shop.com  ',
      );

      expect(code, isNotNull);
      expect(await service.getRecoveryEmail(), 'owner@shop.com');
    });

    test('rejects an invalid recovery email and does not set a PIN', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final service = await context.service();
      final controller = LocalPinAuthController(service);
      addTearDown(controller.dispose);
      // Let the controller's async _initialize finish so it does not race with
      // teardown disposal.
      while (!controller.debugState.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final code = await controller.setupPin(
        pin: '1234',
        confirmPin: '1234',
        recoveryEmail: 'not-an-email',
      );

      expect(code, isNull);
      expect(await service.hasPinConfigured(), isFalse);
      expect(await service.getRecoveryEmail(), isNull);
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_pin_recovery_',
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

  Future<LocalPinAuthService> service() async {
    final appDatabase = await container.read(appDatabaseProvider.future);
    return LocalPinAuthService(appDatabase: appDatabase);
  }

  Future<void> dispose() async {
    try {
      final appDatabase = await container.read(appDatabaseProvider.future);
      await appDatabase.close();
    } catch (_) {}
    container.dispose();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }
}
