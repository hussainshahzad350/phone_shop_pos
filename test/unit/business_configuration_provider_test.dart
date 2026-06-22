import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/business_configuration_repository.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

void main() {
  group('business configuration providers', () {
    test('load defaults when app_settings has no configuration', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      final configuration = await context.container.read(
        businessConfigurationProvider.future,
      );

      expect(configuration.profile, BusinessProfile.mobileOnly);
      expect(
        configuration.source,
        BusinessConfigurationSource.defaultValue,
      );
      expect(configuration.featureFlags.repairModule, isFalse);
    });

    test('load persisted profile and partial flag overrides', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);
      final appDatabase =
          await context.container.read(appDatabaseProvider.future);

      await appDatabase.database.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.businessProfileKey,
          'value': BusinessProfile.mobileOnly.name,
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await appDatabase.database.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.featureFlagsKey,
          'value': jsonEncode(<String, Object?>{'repairModule': false}),
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final configuration = await context.container.read(
        businessConfigurationProvider.future,
      );

      expect(configuration.profile, BusinessProfile.mobileOnly);
      expect(configuration.featureFlags.repairModule, isFalse);
      expect(configuration.featureFlags.imeiStock, isTrue);
      expect(
        configuration.source,
        BusinessConfigurationSource.persisted,
      );
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_business_configuration_',
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
