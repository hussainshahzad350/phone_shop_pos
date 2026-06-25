import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/services/recovery/email_recovery_service.dart';
import 'package:phone_shop_pos/core/services/recovery/otp_client.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

class _FakeOtpClient implements OtpClient {
  _FakeOtpClient({this.sendOk = true, this.verifyOk = true});

  bool sendOk;
  bool verifyOk;
  String? lastEmailSent;
  String? lastVerifyEmail;
  String? lastToken;

  @override
  Future<OtpOutcome> sendCode(String email) async {
    lastEmailSent = email;
    return sendOk
        ? const OtpOutcome.ok()
        : const OtpOutcome.failure('send failed');
  }

  @override
  Future<OtpOutcome> verifyCode({
    required String email,
    required String token,
  }) async {
    lastVerifyEmail = email;
    lastToken = token;
    return verifyOk
        ? const OtpOutcome.ok()
        : const OtpOutcome.failure('bad code');
  }
}

void main() {
  group('EmailRecoveryService', () {
    test('requestResetCode reports noEmail when none is registered', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final auth = await context.authService();
      final fake = _FakeOtpClient();
      final service =
          EmailRecoveryService(otpClient: fake, authService: auth);

      final result = await service.requestResetCode();

      expect(result.status, RecoveryRequestStatus.noEmail);
      expect(fake.lastEmailSent, isNull);
    });

    test('requestResetCode sends to the registered email and masks it',
        () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final auth = await context.authService();
      await auth.setRecoveryEmail('owner@shop.com');
      final fake = _FakeOtpClient();
      final service =
          EmailRecoveryService(otpClient: fake, authService: auth);

      final result = await service.requestResetCode();

      expect(result.status, RecoveryRequestStatus.sent);
      expect(fake.lastEmailSent, 'owner@shop.com');
      expect(result.maskedEmail, contains('@shop.com'));
      expect(result.maskedEmail, isNot('owner@shop.com'));
    });

    test('verifyAndResetPin resets the PIN on a valid code', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final auth = await context.authService();
      await auth.configurePin('1234');
      await auth.setRecoveryEmail('owner@shop.com');
      final fake = _FakeOtpClient(verifyOk: true);
      final service =
          EmailRecoveryService(otpClient: fake, authService: auth);

      final result = await service.verifyAndResetPin(
        token: '123456',
        newPin: '5678',
      );

      expect(result.status, RecoveryResetStatus.success);
      expect(result.newRecoveryCode, isNotNull);
      expect(await auth.verifyPin('5678'), isTrue);
      expect(await auth.verifyPin('1234'), isFalse);
    });

    test('verifyAndResetPin leaves the PIN unchanged on a bad code', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final auth = await context.authService();
      await auth.configurePin('1234');
      await auth.setRecoveryEmail('owner@shop.com');
      final fake = _FakeOtpClient(verifyOk: false);
      final service =
          EmailRecoveryService(otpClient: fake, authService: auth);

      final result = await service.verifyAndResetPin(
        token: '000000',
        newPin: '5678',
      );

      expect(result.status, RecoveryResetStatus.failure);
      expect(await auth.verifyPin('1234'), isTrue);
      expect(await auth.verifyPin('5678'), isFalse);
    });

    test('verifyAndResetPin rejects an invalid new PIN before any network call',
        () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final auth = await context.authService();
      await auth.setRecoveryEmail('owner@shop.com');
      final fake = _FakeOtpClient();
      final service =
          EmailRecoveryService(otpClient: fake, authService: auth);

      final result = await service.verifyAndResetPin(
        token: '123456',
        newPin: '12',
      );

      expect(result.status, RecoveryResetStatus.failure);
      expect(fake.lastToken, isNull);
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_email_recovery_',
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

  Future<LocalPinAuthService> authService() async {
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
