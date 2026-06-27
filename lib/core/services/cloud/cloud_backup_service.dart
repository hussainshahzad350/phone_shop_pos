import 'dart:io';
import 'dart:typed_data';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_storage_client.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

/// Orchestrates off-site backup: make a validated local backup, compress it,
/// and upload it to the shop's private cloud folder; list and restore cloud
/// backups. Reuses the existing [DatabaseBackupService] for the local backup
/// and the atomic restore.
class CloudBackupService {
  CloudBackupService({
    required DatabaseBackupService databaseBackupService,
    required CloudStorageClient storageClient,
    required CloudAuthService authService,
    DateTime Function()? now,
  })  : _databaseBackupService = databaseBackupService,
        _storageClient = storageClient,
        _authService = authService,
        _now = now ?? (() => DateTime.now());

  final DatabaseBackupService _databaseBackupService;
  final CloudStorageClient _storageClient;
  final CloudAuthService _authService;
  final DateTime Function() _now;

  static const AppError _notSignedIn = AppError(
    code: 'cloud_not_signed_in',
    message: 'Sign in to cloud backup first.',
  );

  Future<Result<CloudStorageObject>> backupNow() async {
    final session = await _authService.currentSession();
    if (session == null) {
      return const Failure<CloudStorageObject>(_notSignedIn);
    }

    final localBackup = await _databaseBackupService.createBackup();
    if (localBackup.isFailure) {
      return Failure<CloudStorageObject>(localBackup.asFailure!.error);
    }
    final info = localBackup.asSuccess!.value;

    final rawBytes = await File(info.path).readAsBytes();
    final compressed = Uint8List.fromList(gzip.encode(rawBytes));
    final objectName = 'backup_${FormattingHelpers.backupTimestamp(_now())}.db.gz';
    final path = '${session.userId}/$objectName';

    final upload = await _storageClient.upload(
      path: path,
      bytes: compressed,
      accessToken: session.accessToken,
      contentType: 'application/gzip',
    );
    if (upload.isFailure) {
      return Failure<CloudStorageObject>(upload.asFailure!.error);
    }
    return Success<CloudStorageObject>(
      CloudStorageObject(
        name: objectName,
        sizeBytes: compressed.length,
        createdAt: info.createdAt,
      ),
    );
  }

  Future<Result<List<CloudStorageObject>>> listBackups() async {
    final session = await _authService.currentSession();
    if (session == null) {
      return const Failure<List<CloudStorageObject>>(_notSignedIn);
    }
    return _storageClient.list(
      prefix: '${session.userId}/',
      accessToken: session.accessToken,
    );
  }

  Future<Result<void>> restoreFromCloud(String objectName) async {
    final session = await _authService.currentSession();
    if (session == null) {
      return const Failure<void>(_notSignedIn);
    }

    final download = await _storageClient.download(
      path: '${session.userId}/$objectName',
      accessToken: session.accessToken,
    );
    if (download.isFailure) {
      return Failure<void>(download.asFailure!.error);
    }

    final raw = gzip.decode(download.asSuccess!.value);
    final tempDir = await Directory.systemTemp.createTemp('pos_cloud_restore_');
    final tempPath = '${tempDir.path}/restore.db';
    try {
      await File(tempPath).writeAsBytes(raw, flush: true);
      return await _databaseBackupService.restoreBackup(tempPath);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup of the staging directory.
      }
    }
  }
}
