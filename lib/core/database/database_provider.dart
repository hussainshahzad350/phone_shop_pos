import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/startup/startup_health_service.dart';

final databaseRecoveryEpochProvider = StateProvider<int>((ref) => 0);

final localDatabaseServiceProvider = FutureProvider<LocalDatabaseService>((
  ref,
) async {
  final appDir = await getApplicationSupportDirectory();
  final service = SqliteFfiDatabaseService(rootDirectory: appDir.path);
  await service.initialize();
  return service;
});

final migrationServiceProvider = Provider<MigrationService>(
  (ref) => const MigrationService(),
);

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  ref.watch(databaseRecoveryEpochProvider);
  final localDatabaseService = await ref.watch(localDatabaseServiceProvider.future);
  final migrationService = ref.watch(migrationServiceProvider);
  final appDatabase = AppDatabase(
    localDatabaseService: localDatabaseService,
    migrationService: migrationService,
  );

  await appDatabase.initialize(
    seedDemoData: AppRuntimeConfig.kEnableSeedData,
  );
  await _runAutoBackupIfDue(appDatabase);
  ref.onDispose(appDatabase.close);
  return appDatabase;
});

final sqliteDatabaseProvider = FutureProvider<Database>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return appDatabase.database;
});

final startupHealthServiceProvider = Provider<StartupHealthService>(
  (ref) => const StartupHealthService(),
);

final startupHealthProvider = FutureProvider<StartupHealthStatus>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final startupHealthService = ref.watch(startupHealthServiceProvider);
  final backupDirectoryPath = p.join(p.dirname(appDatabase.filePath), 'backups');
  return startupHealthService.check(
    appDatabase: appDatabase,
    backupDirectoryPath: backupDirectoryPath,
  );
});

Future<void> _runAutoBackupIfDue(AppDatabase appDatabase) async {
  final intervalHours = AppRuntimeConfig.autoBackupIntervalHours;
  if (intervalHours <= 0) {
    return;
  }

  final backupService = DatabaseBackupService(appDatabase: appDatabase);
  try {
    final healthResult = await backupService.getDatabaseHealth();
    final lastBackup = healthResult.asSuccess?.value.lastBackup;
    final backupAge = lastBackup == null
        ? null
        : DateTime.now().difference(lastBackup.createdAt);
    final shouldBackup = lastBackup == null ||
        backupAge == null ||
        backupAge >= Duration(hours: intervalHours);
    if (shouldBackup) {
      await backupService.createBackup();
    }
  } catch (_) {
    // Ignore auto-backup failures so startup remains available for operators.
  }
}
