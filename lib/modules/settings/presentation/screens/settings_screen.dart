import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/modules/settings/presentation/providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isProcessing = false;

  Future<void> _performBackup() async {
    setState(() => _isProcessing = true);
    final service = await ref.read(databaseBackupServiceProvider.future);
    final backupPath = ref.read(backupSettingsProvider).backupDirectoryPath;
    final result = await service.createBackup(directoryPath: backupPath);

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    _refreshHealthProviders();

    final message = result.fold(
      onSuccess: (value) => 'Backup completed: ${value.path}',
      onFailure: (error) => 'Backup failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(
        message,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _performBackup,
        ),
      );
    }
  }

  Future<void> _performRestore() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'SQLite', extensions: <String>['db']),
      ],
    );
    if (file == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: 'Restore Backup',
        message:
            'Restore database from ${p.basename(file.path)}?\n\n'
            'This is destructive and will overwrite current sales history. '
            'Always keep a fresh backup before attempting a restore.',
        confirmLabel: 'Restore',
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);
    final service = await ref.read(databaseBackupServiceProvider.future);
    final result = await service.restoreBackup(file.path);

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    _refreshHealthProviders();
    ref.invalidate(databaseBackupServiceProvider);

    final message = result.fold(
      onSuccess: (_) => 'Restore completed successfully.',
      onFailure: (error) => 'Restore failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(
        message,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _performRestore,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(backupSettingsProvider);
    final healthAsync = ref.watch(databaseHealthProvider);
    final startupHealthAsync = ref.watch(startupHealthFromSettingsProvider);
    final printQueue = ref.watch(invoicePrintQueueProvider);

    return Scaffold(
      body: AppLoadingOverlay(
        isLoading: _isProcessing,
        label: 'Processing...',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _showAboutDialog,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('About'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Deployment Metadata',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Version: ${AppRuntimeConfig.fullVersion}'),
                      Text('Channel: ${AppRuntimeConfig.releaseChannel}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: startupHealthAsync.when(
                    data: (status) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Startup Health',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        AppStatusBadge(
                          label: status.summary,
                          color: status.isHealthy ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        Text('DB location: ${status.databasePath}'),
                        Text('Backup location: ${status.backupDirectoryPath}'),
                        Text(
                          'Checked: ${FormattingHelpers.dateYmdHm(status.checkedAt)}',
                        ),
                        if (status.warnings.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          ...status.warnings.map(
                            (warning) => Text('• $warning'),
                          ),
                        ],
                      ],
                    ),
                    loading: () => const SizedBox(
                      height: 90,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 90,
                      child: Center(child: Text('Failed to load startup health.')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Backup & Restore',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    final path = await getDirectoryPath(
                                      confirmButtonText: 'Use Folder',
                                    );
                                    if (path == null) {
                                      return;
                                    }
                                    ref
                                        .read(backupSettingsProvider.notifier)
                                        .setBackupDirectory(path);
                                    _refreshHealthProviders();
                                  },
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Select Backup Folder'),
                          ),
                          FilledButton.icon(
                            onPressed: _isProcessing ? null : _performBackup,
                            icon: const Icon(Icons.backup_outlined),
                            label: const Text('One-Click Backup'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _isProcessing ? null : _performRestore,
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore Backup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Backup folder: ${settings.backupDirectoryPath ?? 'Default app backup folder'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: healthAsync.when(
                    data: (health) {
                      final lastBackup = health.lastBackup;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Database Health',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Database path: ${health.databasePath}'),
                          Text('Database size: ${_formatBytes(health.sizeBytes)}'),
                          Text(
                            'Integrity check: ${health.integrityOk ? 'OK' : 'FAILED'}',
                          ),
                          Text(
                            'Last backup: ${_backupPathText(lastBackup)}',
                          ),
                          Text(
                            'Last backup time: ${_backupTimeText(lastBackup)}',
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 90,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 90,
                      child: Center(child: Text('Failed to load database health.')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Pending Invoice Print Queue',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (printQueue.isEmpty)
                        const Text('No pending print jobs.')
                      else
                        ...printQueue.map(
                          (job) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(job.invoiceNumber),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Attempts: ${job.attempts} • '
                                  'Queued: ${FormattingHelpers.dateYmdHm(job.createdAt)}',
                                ),
                                if (job.lastError != null)
                                  Text('Last error: ${job.lastError}'),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'Retry print',
                              onPressed: () async {
                                final result = await ref
                                    .read(invoicePrintQueueProvider.notifier)
                                    .printJob(
                                      jobId: job.id,
                                      paperSize: InvoicePaperSize.thermal80,
                                    );
                                if (!mounted) {
                                  return;
                                }
                                final message = result.fold(
                                  onSuccess: (value) =>
                                      'Print job spooled: ${value.path}',
                                  onFailure: (error) =>
                                      'Retry failed: ${error.message}',
                                );
                                if (result.isSuccess) {
                                  AppNotifier.success(message);
                                } else {
                                  AppNotifier.error(message);
                                }
                              },
                              icon: const Icon(Icons.print_outlined),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(2)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppRuntimeConfig.appName,
      applicationVersion: AppRuntimeConfig.fullVersion,
      children: const <Widget>[
        Text('Desktop-first offline POS for mobile shops.'),
      ],
    );
  }

  void _refreshHealthProviders() {
    ref.invalidate(databaseHealthProvider);
    ref.invalidate(startupHealthFromSettingsProvider);
  }

  String _backupPathText(BackupInfo? backup) {
    if (backup == null) {
      return 'No backups yet';
    }
    return backup.path;
  }

  String _backupTimeText(BackupInfo? backup) {
    if (backup == null) {
      return '-';
    }
    return FormattingHelpers.dateYmdHm(backup.createdAt);
  }
}
