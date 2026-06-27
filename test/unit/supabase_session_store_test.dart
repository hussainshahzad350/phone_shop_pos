import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session_store.dart';

void main() {
  group('SupabaseSessionStore', () {
    test('write, read and clear a session', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase =
          await context.container.read(appDatabaseProvider.future);
      final store = SupabaseSessionStore(appDatabase: appDatabase);

      expect(await store.read(), isNull);
      expect(await store.isSignedIn(), isFalse);

      final session = SupabaseSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        userId: 'user-1',
        expiresAt: DateTime.utc(2026, 6, 26, 1),
        email: 'owner@shop.com',
      );
      await store.write(session);

      final read = await store.read();
      expect(read, isNotNull);
      expect(read!.userId, 'user-1');
      expect(await store.isSignedIn(), isTrue);

      await store.clear();
      expect(await store.read(), isNull);
      expect(await store.isSignedIn(), isFalse);
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_session_store_',
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
    } catch (_) {}
    container.dispose();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }
}
