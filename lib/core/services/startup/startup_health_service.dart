import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/database_constants.dart';

class StartupHealthStatus {
  const StartupHealthStatus({
    required this.databasePath,
    required this.backupDirectoryPath,
    required this.integrityOk,
    required this.databaseWritable,
    required this.backupWritable,
    required this.pathLengthSafe,
    required this.warnings,
    required this.checkedAt,
  });

  final String databasePath;
  final String backupDirectoryPath;
  final bool integrityOk;
  final bool databaseWritable;
  final bool backupWritable;
  final bool pathLengthSafe;
  final List<String> warnings;
  final DateTime checkedAt;

  bool get isHealthy =>
      integrityOk &&
      databaseWritable &&
      backupWritable &&
      pathLengthSafe;

  String get summary => isHealthy ? 'Healthy' : 'Attention required';
}

class StartupHealthService {
  const StartupHealthService();

  Future<StartupHealthStatus> check({
    required AppDatabase appDatabase,
    String? backupDirectoryPath,
  }) async {
    final databasePath = appDatabase.filePath;
    final resolvedBackupPath =
        backupDirectoryPath ?? p.join(p.dirname(databasePath), 'backups');

    final warnings = <String>[];

    final dbFile = File(databasePath);
    final databaseWritable = await _canWrite(dbFile.parent.path);
    if (!databaseWritable) {
      warnings.add('Database directory is not writable.');
    }

    final backupWritable = await _canWrite(resolvedBackupPath);
    if (!backupWritable) {
      warnings.add('Backup directory is not writable.');
    }

    final pathLengthSafe =
        databasePath.length <= DatabaseConstants.windowsRecommendedPathLength;
    if (!pathLengthSafe) {
      warnings.add(
        'Database path is long for Windows and may fail on older deployments.',
      );
    }

    final integrityRows = await appDatabase.database.rawQuery(
      'PRAGMA integrity_check;',
    );
    final integrityValue = integrityRows.isEmpty
        ? ''
        : integrityRows.first.values.first.toString().toLowerCase();
    final integrityOk = integrityValue == 'ok';
    if (!integrityOk) {
      warnings.add('SQLite integrity check failed.');
    }

    return StartupHealthStatus(
      databasePath: databasePath,
      backupDirectoryPath: resolvedBackupPath,
      integrityOk: integrityOk,
      databaseWritable: databaseWritable,
      backupWritable: backupWritable,
      pathLengthSafe: pathLengthSafe,
      warnings: warnings,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  Future<bool> _canWrite(String directoryPath) async {
    final directory = Directory(directoryPath);
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final probe = File(
        p.join(
          directory.path,
          '.write_probe_${DateTime.now().toUtc().microsecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
