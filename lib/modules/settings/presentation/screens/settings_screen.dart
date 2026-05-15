import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
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
    ref.invalidate(databaseHealthProvider);

    final message = result.fold(
      onSuccess: (value) => 'Backup completed: ${value.path}',
      onFailure: (error) => 'Backup failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(message);
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
            'Restore database from ${p.basename(file.path)}? This will overwrite current data.',
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
    ref.invalidate(databaseHealthProvider);
    ref.invalidate(databaseBackupServiceProvider);

    final message = result.fold(
      onSuccess: (_) => 'Restore completed successfully.',
      onFailure: (error) => 'Restore failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(backupSettingsProvider);
    final healthAsync = ref.watch(databaseHealthProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: <Widget>[
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
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
                                  ref.invalidate(databaseHealthProvider);
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
                  data: (health) => Column(
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
                        'Last backup: ${health.lastBackup == null ? 'No backups yet' : health.lastBackup!.path}',
                      ),
                    ],
                  ),
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
            const Card(
              child: ListTile(
                title: Text('Receipt Settings'),
                subtitle: Text('Placeholder for future receipt configurations.'),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                title: Text('Printer Settings'),
                subtitle: Text('Placeholder for future printer setup and device mapping.'),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                title: Text('App Preferences'),
                subtitle: Text('Placeholder for theme, language, and shortcut preferences.'),
              ),
            ),
          ],
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
}
