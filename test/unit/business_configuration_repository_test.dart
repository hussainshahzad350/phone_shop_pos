import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_configuration_repository.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

void main() {
  group('BusinessConfigurationRepository', () {
    test('save writes profile, flags, and version and load resolves them',
        () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      final appDatabase =
          await context.container.read(appDatabaseProvider.future);
      final repository =
          BusinessConfigurationRepository(appDatabase: appDatabase);

      final defaults = BusinessConfiguration.defaults();
      final configToSave = defaults.copyWith(
        profile: BusinessProfile.mobileOnly,
      );
      final savedConfig = configToSave.copyWith(
        featureFlags: configToSave.featureFlags.copyWith(repairModule: false),
      );

      await repository.save(savedConfig);

      final loadedConfig = await repository.load(defaults);

      expect(loadedConfig.profile, BusinessProfile.mobileOnly);
      expect(loadedConfig.featureFlags.repairModule, isFalse);
      expect(loadedConfig.schemaVersion, savedConfig.schemaVersion);
      expect(loadedConfig.source, BusinessConfigurationSource.persisted);
    });

    test('load returns defaults safely when given malformed data', () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      final appDatabase =
          await context.container.read(appDatabaseProvider.future);
      final repository =
          BusinessConfigurationRepository(appDatabase: appDatabase);
      final defaults = BusinessConfiguration.defaults();

      final db = appDatabase.database;
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

      await db.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.businessProfileKey,
          'value': 'unknown_profile_value',
          'updated_at': now,
        },
      );
      await db.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.featureFlagsKey,
          'value': '{ malformed json... ',
          'updated_at': now,
        },
      );
      await db.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.configurationVersionKey,
          'value': 'not a number',
          'updated_at': now,
        },
      );

      final loadedConfig = await repository.load(defaults);

      expect(loadedConfig.profile, defaults.profile);
      expect(loadedConfig.featureFlags, defaults.featureFlags);
      expect(loadedConfig.schemaVersion, defaults.schemaVersion);
      expect(loadedConfig.source, BusinessConfigurationSource.mixed);
    });

    test('load returns defaults safely when feature flags is not a json object',
        () async {
      final context = await _createContainer();
      addTearDown(context.dispose);

      final appDatabase =
          await context.container.read(appDatabaseProvider.future);
      final repository =
          BusinessConfigurationRepository(appDatabase: appDatabase);
      final defaults = BusinessConfiguration.defaults();

      final db = appDatabase.database;
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

      await db.insert(
        TableNames.appSettings,
        <String, Object?>{
          'key': BusinessConfigurationRepository.featureFlagsKey,
          'value': '["array", "instead", "of", "object"]',
          'updated_at': now,
        },
      );

      final loadedConfig = await repository.load(defaults);

      expect(loadedConfig.featureFlags, defaults.featureFlags);
    });
  });
}

Future<_ProviderTestContext> _createContainer() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'phone_shop_pos_business_configuration_repository_',
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
