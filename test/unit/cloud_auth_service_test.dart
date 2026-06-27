import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_client.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_service.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session_store.dart';

class _FakeAuthClient implements CloudAuthClient {
  Result<SupabaseSession>? verifyResult;
  Result<SupabaseSession>? refreshResult;
  int sendCount = 0;
  int refreshCount = 0;

  @override
  Future<Result<void>> sendCode(String email) async {
    sendCount++;
    return const Success<void>(null);
  }

  @override
  Future<Result<SupabaseSession>> verify({
    required String email,
    required String token,
  }) async {
    return verifyResult ??
        const Failure<SupabaseSession>(
          AppError(code: 'x', message: 'no result configured'),
        );
  }

  @override
  Future<Result<SupabaseSession>> refresh(String refreshToken) async {
    refreshCount++;
    return refreshResult ??
        const Failure<SupabaseSession>(
          AppError(code: 'x', message: 'no result configured'),
        );
  }
}

SupabaseSession _session({
  String accessToken = 'access',
  required DateTime expiresAt,
}) {
  return SupabaseSession(
    accessToken: accessToken,
    refreshToken: 'refresh',
    userId: 'user-1',
    expiresAt: expiresAt,
    email: 'owner@shop.com',
  );
}

void main() {
  group('CloudAuthService', () {
    test('signIn persists the session on success', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final store = await context.store();
      final client = _FakeAuthClient()
        ..verifyResult = Success<SupabaseSession>(
          _session(expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1))),
        );
      final service = CloudAuthService(client: client, store: store);

      final result = await service.signIn(email: 'owner@shop.com', token: '123456');

      expect(result.isSuccess, isTrue);
      expect(await store.isSignedIn(), isTrue);
      expect(await service.signedInEmail(), 'owner@shop.com');
    });

    test('currentSession returns the stored session when still valid', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final store = await context.store();
      await store.write(
        _session(expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1))),
      );
      final client = _FakeAuthClient();
      final service = CloudAuthService(client: client, store: store);

      final session = await service.currentSession();

      expect(session, isNotNull);
      expect(client.refreshCount, 0);
    });

    test('currentSession refreshes an expired session', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final store = await context.store();
      await store.write(
        _session(
          accessToken: 'old',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      );
      final client = _FakeAuthClient()
        ..refreshResult = Success<SupabaseSession>(
          _session(
            accessToken: 'fresh',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
        );
      final service = CloudAuthService(client: client, store: store);

      final session = await service.currentSession();

      expect(client.refreshCount, 1);
      expect(session!.accessToken, 'fresh');
      expect((await store.read())!.accessToken, 'fresh');
    });

    test('currentSession is null when not signed in', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final store = await context.store();
      final service = CloudAuthService(client: _FakeAuthClient(), store: store);

      expect(await service.currentSession(), isNull);
    });

    test('signOut clears the session', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final store = await context.store();
      await store.write(
        _session(expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1))),
      );
      final service = CloudAuthService(client: _FakeAuthClient(), store: store);

      await service.signOut();

      expect(await service.isSignedIn(), isFalse);
    });
  });
}

Future<_Ctx> _createContainer() async {
  final rootDirectory =
      await Directory.systemTemp.createTemp('phone_shop_pos_cloud_auth_');
  final container = ProviderContainer(
    overrides: <Override>[
      localDatabaseServiceProvider.overrideWith((ref) async {
        final service = SqliteFfiDatabaseService(rootDirectory: rootDirectory.path);
        await service.initialize();
        return service;
      }),
    ],
  );
  return _Ctx(container: container, rootDirectory: rootDirectory);
}

class _Ctx {
  const _Ctx({required this.container, required this.rootDirectory});

  final ProviderContainer container;
  final Directory rootDirectory;

  Future<SupabaseSessionStore> store() async {
    final appDatabase = await container.read(appDatabaseProvider.future);
    return SupabaseSessionStore(appDatabase: appDatabase);
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
