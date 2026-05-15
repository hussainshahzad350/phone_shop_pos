import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';

class BackupSettingsState {
  const BackupSettingsState({this.backupDirectoryPath});

  final String? backupDirectoryPath;

  BackupSettingsState copyWith({
    String? backupDirectoryPath,
    bool clearBackupDirectoryPath = false,
  }) {
    return BackupSettingsState(
      backupDirectoryPath: clearBackupDirectoryPath
          ? null
          : backupDirectoryPath ?? this.backupDirectoryPath,
    );
  }
}

class BackupSettingsNotifier extends StateNotifier<BackupSettingsState> {
  BackupSettingsNotifier() : super(const BackupSettingsState());

  void setBackupDirectory(String? path) {
    if (path == null || path.trim().isEmpty) {
      state = state.copyWith(clearBackupDirectoryPath: true);
      return;
    }
    state = state.copyWith(backupDirectoryPath: path.trim());
  }
}

final backupSettingsProvider =
    StateNotifierProvider<BackupSettingsNotifier, BackupSettingsState>(
      (ref) => BackupSettingsNotifier(),
    );

final databaseBackupServiceProvider = FutureProvider<DatabaseBackupService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return DatabaseBackupService(appDatabase: appDatabase);
});

final databaseHealthProvider = FutureProvider<DatabaseHealthInfo>((ref) async {
  final service = await ref.watch(databaseBackupServiceProvider.future);
  final backupSettings = ref.watch(backupSettingsProvider);
  final result = await service.getDatabaseHealth(
    backupDirectoryPath: backupSettings.backupDirectoryPath,
  );

  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => const DatabaseHealthInfo(
      databasePath: '-',
      sizeBytes: 0,
      integrityOk: false,
    ),
  );
});
