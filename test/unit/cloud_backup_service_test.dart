import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_client.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_storage_client.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session_store.dart';

class _FakeStorage implements CloudStorageClient {
  final Map<String, Uint8List> objects = <String, Uint8List>{};

  @override
  Future<Result<void>> upload({
    required String path,
    required Uint8List bytes,
    required String accessToken,
    String contentType = 'application/octet-stream',
  }) async {
    objects[path] = bytes;
    return const Success<void>(null);
  }

  @override
  Future<Result<List<CloudStorageObject>>> list({
    required String prefix,
    required String accessToken,
  }) async {
    final items = objects.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map(
          (entry) => CloudStorageObject(
            name: entry.key.substring(prefix.length),
            sizeBytes: entry.value.length,
          ),
        )
        .toList(growable: false);
    return Success<List<CloudStorageObject>>(items);
  }

  @override
  Future<Result<Uint8List>> download({
    required String path,
    required String accessToken,
  }) async {
    final bytes = objects[path];
    if (bytes == null) {
      return const Failure<Uint8List>(
        AppError(code: 'not_found', message: 'No such object'),
      );
    }
    return Success<Uint8List>(bytes);
  }

  @override
  Future<Result<void>> delete({
    required String path,
    required String accessToken,
  }) async {
    objects.remove(path);
    return const Success<void>(null);
  }
}

void main() {
  group('CloudBackupService', () {
    test('backupNow uploads a gzipped backup to the account folder', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase = await context.appDatabase();
      final storage = _FakeStorage();
      final service = await context.service(appDatabase, storage);

      final result = await service.backupNow();

      expect(result.isSuccess, isTrue);
      expect(storage.objects.length, 1);
      final entry = storage.objects.entries.first;
      expect(entry.key.startsWith('user-1/'), isTrue);
      expect(entry.key.endsWith('.db.gz'), isTrue);
      // gzip magic header bytes.
      expect(entry.value[0], 0x1f);
      expect(entry.value[1], 0x8b);
    });

    test('backupNow fails when not signed in', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase = await context.appDatabase();
      final storage = _FakeStorage();
      final service = await context.service(
        appDatabase,
        storage,
        signedIn: false,
      );

      final result = await service.backupNow();

      expect(result.isFailure, isTrue);
      expect(result.asFailure!.error.code, 'cloud_not_signed_in');
    });

    test('restoreFromCloud restores an uploaded backup end to end', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase = await context.appDatabase();
      final storage = _FakeStorage();
      final service = await context.service(appDatabase, storage);

      final backup = await service.backupNow();
      expect(backup.isSuccess, isTrue);
      final name = backup.asSuccess!.value.name;

      final restore = await service.restoreFromCloud(name);

      expect(restore.isSuccess, isTrue);
    });
  });
}

Future<_Ctx> _createContainer() async {
  final rootDirectory =
      await Directory.systemTemp.createTemp('phone_shop_pos_cloud_backup_');
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

  Future<AppDatabase> appDatabase() => container.read(appDatabaseProvider.future);

  Future<CloudBackupService> service(
    AppDatabase appDatabase,
    CloudStorageClient storage, {
    bool signedIn = true,
  }) async {
    final store = SupabaseSessionStore(appDatabase: appDatabase);
    if (signedIn) {
      await store.write(
        SupabaseSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          email: 'owner@shop.com',
        ),
      );
    }
    final authService = CloudAuthService(client: _NoopAuthClient(), store: store);
    return CloudBackupService(
      databaseBackupService: DatabaseBackupService(appDatabase: appDatabase),
      storageClient: storage,
      authService: authService,
    );
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

class _NoopAuthClient implements CloudAuthClient {
  @override
  Future<Result<void>> sendCode(String email) async =>
      const Success<void>(null);

  @override
  Future<Result<SupabaseSession>> verify({
    required String email,
    required String token,
  }) async =>
      const Failure<SupabaseSession>(
        AppError(code: 'unused', message: 'unused'),
      );

  @override
  Future<Result<SupabaseSession>> refresh(String refreshToken) async =>
      const Failure<SupabaseSession>(
        AppError(code: 'unused', message: 'unused'),
      );
}
