import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    required this.valid,
  });

  final String path;
  final DateTime createdAt;
  final int sizeBytes;
  final bool valid;
}

class DatabaseHealthInfo {
  const DatabaseHealthInfo({
    required this.databasePath,
    required this.sizeBytes,
    required this.integrityOk,
    this.lastBackup,
  });

  final String databasePath;
  final int sizeBytes;
  final bool integrityOk;
  final BackupInfo? lastBackup;
}

class DatabaseBackupService with BaseRepositoryGuard {
  DatabaseBackupService({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<BackupInfo>> createBackup({String? directoryPath}) {
    return guard<BackupInfo>(() async {
      final now = DateTime.now();
      final folder = Directory(
        directoryPath ?? p.join(p.dirname(_appDatabase.filePath), 'backups'),
      );
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final checkpointRows = await _appDatabase.database.rawQuery(
        'PRAGMA wal_checkpoint(FULL);',
      );
      if (checkpointRows.isNotEmpty) {
        final busyValue = (checkpointRows.first['busy'] as num?)?.toInt() ?? 0;
        if (busyValue != 0) {
          throw StateError('Database is busy; checkpoint failed before backup.');
        }
      }

      final fileName = _buildBackupFileName(now);
      final outputPath = p.join(folder.path, fileName);
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      await File(_appDatabase.filePath).copy(outputPath);

      final valid = await _validateBackup(outputPath);
      if (!valid) {
        throw StateError('Backup validation failed.');
      }

      final file = File(outputPath);
      final info = BackupInfo(
        path: outputPath,
        createdAt: now,
        sizeBytes: await file.length(),
        valid: true,
      );

      await _writeLastBackupInfo(info);
      return info;
    }, operation: 'create_database_backup');
  }

  Future<Result<void>> restoreBackup(String backupFilePath) {
    return guard<void>(() async {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw StateError('Backup file not found.');
      }

      // Validate the backup BEFORE touching the live database.
      final isValid = await _validateBackup(backupFilePath);
      if (!isValid) {
        throw StateError('Selected backup file is invalid or corrupted.');
      }

      final targetDbPath = _appDatabase.filePath;
      final targetDbFile = File(targetDbPath);

      // Stage the backup in a temp file so the live DB is never exposed to
      // a partially-written copy if the process is interrupted.
      final tempRestorePath = '$targetDbPath.restore_tmp';
      final tempRestoreFile = File(tempRestorePath);

      try {
        // 1. Copy backup → temp staging file.
        await backupFile.copy(tempRestorePath);

        // 2. Validate the staged copy independently (catches copy-time errors).
        final stagedValid = await _validateBackup(tempRestorePath);
        if (!stagedValid) {
          throw StateError('Staged restore copy failed integrity check.');
        }

        // 3. Close the live database — no writes are possible after this point.
        await _appDatabase.close();

        // 4. Atomic swap: rename live DB to .bak, then rename staged copy to
        //    live path.  If rename fails (cross-device etc.), fall back to
        //    copy + delete.
        final backupSafePath = '$targetDbPath.pre_restore_bak';
        final backupSafeFile = File(backupSafePath);
        // Remove any stale pre-restore backup first.
        if (await backupSafeFile.exists()) {
          await backupSafeFile.delete();
        }

        try {
          // Try atomic rename (same filesystem).
          if (await targetDbFile.exists()) {
            await targetDbFile.rename(backupSafePath);
          }
          await tempRestoreFile.rename(targetDbPath);
        } catch (_) {
          // Fallback: copy + delete (different filesystems / permissions).
          if (await targetDbFile.exists()) {
            await targetDbFile.copy(backupSafePath);
            await targetDbFile.delete();
          }
          await tempRestoreFile.copy(targetDbPath);
        }

        // 5. Reopen and verify the restored database.
        try {
          await _appDatabase.initialize(seedDemoData: false);

          final healthRows = await _appDatabase.database.rawQuery(
            'PRAGMA integrity_check;',
          );
          final healthValue =
              healthRows.isNotEmpty
                  ? healthRows.first.values.first.toString().toLowerCase()
                  : '';

          if (healthValue != 'ok') {
            throw StateError('Restored database failed integrity check.');
          }
        } catch (reopenError) {
          // Rollback: restore the pre-restore backup if available.
          await _appDatabase.close();
          if (await backupSafeFile.exists()) {
            if (await targetDbFile.exists()) {
              await targetDbFile.delete();
            }
            await backupSafeFile.copy(targetDbPath);
            await _appDatabase.initialize(seedDemoData: false);
          }
          throw StateError(
            'Restore failed and was rolled back: $reopenError',
          );
        }

        // 6. Cleanup: remove staging artifacts after a successful restore.
        //    When atomic rename succeeded, tempRestoreFile no longer exists
        //    (it was renamed); when fallback copy was used, it still exists.
        //    Unconditionally check-and-delete covers both cases cleanly.
        if (await backupSafeFile.exists()) {
          await backupSafeFile.delete();
        }
        if (await tempRestoreFile.exists()) {
          await tempRestoreFile.delete();
        }

        final info = BackupInfo(
          path: backupFilePath,
          createdAt: DateTimeHelpers.nowUtc(),
          sizeBytes: await backupFile.length(),
          valid: true,
        );
        await _writeLastBackupInfo(info);
      } catch (_) {
        // Best-effort cleanup of the temp staging file on any error.
        if (await tempRestoreFile.exists()) {
          try {
            await tempRestoreFile.delete();
          } catch (_) {
            // Ignore cleanup errors.
          }
        }
        rethrow;
      }
    }, operation: 'restore_database_backup');
  }

  Future<Result<bool>> validateBackup(String backupFilePath) {
    return guard<bool>(() async => _validateBackup(backupFilePath), operation: 'validate_backup');
  }

  Future<Result<DatabaseHealthInfo>> getDatabaseHealth({String? backupDirectoryPath}) {
    return guard<DatabaseHealthInfo>(() async {
      final dbPath = _appDatabase.filePath;
      final dbFile = File(dbPath);
      final sizeBytes = await dbFile.length();
      final integrityRows = await _appDatabase.database.rawQuery(
        'PRAGMA integrity_check;',
      );
      final integrityValue = integrityRows.first.values.first.toString();
      final lastBackup = await _readLastBackupInfo(
        backupDirectoryPath:
            backupDirectoryPath ?? p.join(p.dirname(dbPath), 'backups'),
      );

      return DatabaseHealthInfo(
        databasePath: dbPath,
        sizeBytes: sizeBytes,
        integrityOk: integrityValue.toLowerCase() == 'ok',
        lastBackup: lastBackup,
      );
    }, operation: 'database_health_check');
  }

  Future<bool> _validateBackup(String backupFilePath) async {
    final file = File(backupFilePath);
    if (!await file.exists()) {
      return false;
    }

    final opened = await databaseFactoryFfi.openDatabase(
      backupFilePath,
      options: OpenDatabaseOptions(readOnly: true),
    );

    try {
      final checkRows = await opened.rawQuery('PRAGMA integrity_check;');
      if (checkRows.isEmpty) {
        return false;
      }
      return checkRows.first.values.first.toString().toLowerCase() == 'ok';
    } finally {
      await opened.close();
    }
  }

  String _buildBackupFileName(DateTime dateTime) {
    final suffix = FormattingHelpers.backupTimestamp(dateTime);
    return 'backup_$suffix.db';
  }

  Future<void> _writeLastBackupInfo(BackupInfo info) async {
    final file = File(p.join(p.dirname(_appDatabase.filePath), 'last_backup.json'));
    final payload = <String, Object?>{
      'path': info.path,
      'createdAt': info.createdAt.toUtc().toIso8601String(),
      'sizeBytes': info.sizeBytes,
      'valid': info.valid,
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<BackupInfo?> _readLastBackupInfo({required String backupDirectoryPath}) async {
    final metadataFile = File(
      p.join(p.dirname(_appDatabase.filePath), 'last_backup.json'),
    );

    if (await metadataFile.exists()) {
      try {
        final decoded = jsonDecode(await metadataFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          return BackupInfo(
            path: decoded['path'] as String,
            createdAt: DateTime.parse(decoded['createdAt'] as String).toLocal(),
            sizeBytes: decoded['sizeBytes'] as int? ?? 0,
            valid: decoded['valid'] as bool? ?? false,
          );
        }
      } catch (_) {
        // ignore invalid metadata and fallback to directory scan
      }
    }

    final directory = Directory(backupDirectoryPath);
    if (!await directory.exists()) {
      return null;
    }

    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.basename(file.path).startsWith('backup_'))
        .toList();

    if (files.isEmpty) {
      return null;
    }

    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    final latest = files.first;
    return BackupInfo(
      path: latest.path,
      createdAt: latest.lastModifiedSync(),
      sizeBytes: await latest.length(),
      valid: true,
    );
  }
}
