import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

class BusinessConfigurationRepository {
  const BusinessConfigurationRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static const String businessProfileKey = 'business_profile';
  static const String configurationVersionKey =
      'business_configuration_version';

  final AppDatabase _appDatabase;

  Future<BusinessConfiguration> load(
    BusinessConfiguration defaults, {
    DateTime? loadedAt,
  }) async {
    final profileValue = await _readSetting(businessProfileKey);
    final versionValue = await _readSetting(configurationVersionKey);

    final parsedProfile = BusinessProfile.tryParse(profileValue);
    final parsedVersion = int.tryParse(versionValue?.trim() ?? '');

    final hasAnyPersistedValue =
        profileValue != null || versionValue != null;
    final hasAnyValidPersistedValue =
        parsedProfile != null || parsedVersion != null;

    final source = !hasAnyPersistedValue
        ? BusinessConfigurationSource.defaultValue
        : hasAnyValidPersistedValue
            ? BusinessConfigurationSource.persisted
            : BusinessConfigurationSource.mixed;

    return defaults.copyWith(
      profile: parsedProfile ?? defaults.profile,
      source: source,
      schemaVersion: parsedVersion ?? defaults.schemaVersion,
      loadedAt: loadedAt ?? DateTimeHelpers.nowUtc(),
    );
  }

  Future<void> save(BusinessConfiguration configuration) async {
    await _writeSetting(
      businessProfileKey,
      configuration.profile.name,
    );
    await _writeSetting(
      configurationVersionKey,
      configuration.schemaVersion.toString(),
    );
  }

  Future<String?> _readSetting(String key) async {
    final rows = await _appDatabase.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _writeSetting(String key, String value) async {
    await _appDatabase.database.insert(
      TableNames.appSettings,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
