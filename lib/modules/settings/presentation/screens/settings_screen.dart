import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/print_job_repository.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/settings/presentation/providers/settings_providers.dart';
import 'package:phone_shop_pos/shared/providers/core_providers.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';
import 'package:phone_shop_pos/core/config/business_configuration.dart';

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
    final result = await ref
        .read(operationManagerProvider.notifier)
        .track<Result<BackupInfo>>(
          code: 'backup_database',
          label: 'Creating backup',
          progressLabel: 'Creating a safe SQLite backup',
          action: (_) => service.createBackup(directoryPath: backupPath),
        );

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
      useRootNavigator: true,
      builder: (context) => AppConfirmationDialog(
        title: 'Restore Backup',
        message: 'Restore database from ${p.basename(file.path)}?\n\n'
            'This will replace the live shop data with the selected backup.\n'
            'Before continuing:\n'
            '• Make a fresh backup of the current shop data\n'
            '• Ensure all cashiers stop using the app\n'
            '• Be ready to verify the restored sales after restart',
        confirmLabel: 'Restore',
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);
    final service = await ref.read(databaseBackupServiceProvider.future);
    final result =
        await ref.read(operationManagerProvider.notifier).track<Result<void>>(
              code: 'restore_database',
              label: 'Restoring backup',
              progressLabel: 'Replacing live database with selected backup',
              action: (_) => service.restoreBackup(file.path),
            );

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    _refreshHealthProviders();
    if (result.isSuccess) {
      ref.read(databaseRecoveryEpochProvider.notifier).state++;
      ref.invalidate(appDatabaseProvider);
      ref.invalidate(sqliteDatabaseProvider);
      ref.invalidate(databaseBackupServiceProvider);
    }

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

  Future<void> _retryPrintJob(InvoicePrintJob job) async {
    final result = await ref.read(invoicePrintQueueProvider.notifier).printJob(
          jobId: job.id,
          paperSize: InvoicePaperSize.thermal80,
        );
    if (!mounted) {
      return;
    }
    final message = result.fold(
      onSuccess: (value) => 'Receipt queued to spool: ${value.path}',
      onFailure: (error) => 'Print retry failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(message);
    }
  }

  Future<void> _cancelPrintJob(InvoicePrintJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const AppConfirmationDialog(
        title: 'Cancel queued receipt?',
        message:
            'This will remove the receipt from the active print queue. Use this only if the receipt is no longer needed.',
        confirmLabel: 'Cancel Receipt',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result =
        await ref.read(invoicePrintQueueProvider.notifier).cancel(job.id);
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      AppNotifier.info('Receipt removed from the active queue.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _showChangePinDialog() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final authController = ref.read(localPinAuthControllerProvider.notifier);
    authController.clearError();

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final authState = dialogRef.watch(localPinAuthControllerProvider);
          return AlertDialog(
            title: const Text('Change PIN'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: currentPinController,
                    decoration: appDesktopInputDecoration(
                      labelText: 'Current PIN',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPinController,
                    decoration: appDesktopInputDecoration(
                      labelText: 'New PIN (4-6 digits)',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPinController,
                    decoration: appDesktopInputDecoration(
                      labelText: 'Confirm New PIN',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  if (authState.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      authState.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: authState.isBusy
                    ? null
                    : () {
                        authController.clearError();
                        Navigator.of(context).pop();
                      },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: authState.isBusy
                    ? null
                    : () async {
                        final changed = await authController.changePin(
                          currentPin: currentPinController.text,
                          newPin: newPinController.text,
                          confirmPin: confirmPinController.text,
                        );
                        if (!mounted || !changed) {
                          return;
                        }
                        authController.clearError();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        AppNotifier.success('PIN changed successfully.');
                      },
                child: const Text('Change PIN'),
              ),
            ],
          );
        },
      ),
    );

    currentPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();
  }

  Future<void> _showRecoveryCodeDialog({required String recoveryCode}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('New Recovery Code'),
        content: SelectableText(
          'Store this code offline. Use it only if you forget your PIN:\n\n$recoveryCode',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I saved it'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeBusinessProfile(BusinessProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AppConfirmationDialog(
        title: 'Change Business Profile?',
        message:
            'Changing the business profile will update all feature flags.\n\n'
            'This will restart the application to apply the new configuration.',
        confirmLabel: 'Change Profile',
        cancelLabel: 'Cancel',
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);
    final repository = await ref.read(businessConfigurationRepositoryProvider.future);
    final newConfig = BusinessConfiguration(
      profile: profile,
      featureFlags: _getFeatureFlagsForProfile(profile),
      source: BusinessConfigurationSource.persisted,
      schemaVersion: BusinessConfiguration.currentSchemaVersion,
      loadedAt: DateTime.now().toUtc(),
    );

    await repository.save(newConfig);

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);

    AppNotifier.success('Business profile changed successfully.');
    ref.invalidate(businessConfigurationProvider);
    ref.invalidate(appDatabaseProvider);
    ref.invalidate(sqliteDatabaseProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  FeatureFlags _getFeatureFlagsForProfile(BusinessProfile profile) {
    switch (profile) {
      case BusinessProfile.mobileOnly:
        return const FeatureFlags(
          imeiStock: true,
          qtyStock: true,
          repairModule: false,
          accessoriesModule: false,
          dealerIssueModule: false,
          reports: true,
          navigationStyle: false,
        );
      case BusinessProfile.mobileAccessories:
        return const FeatureFlags(
          imeiStock: true,
          qtyStock: true,
          repairModule: false,
          accessoriesModule: true,
          dealerIssueModule: false,
          reports: true,
          navigationStyle: false,
        );
      case BusinessProfile.repairShop:
        return const FeatureFlags(
          imeiStock: true,
          qtyStock: true,
          repairModule: true,
          accessoriesModule: false,
          dealerIssueModule: false,
          reports: true,
          navigationStyle: false,
        );
      case BusinessProfile.hybrid:
        return const FeatureFlags(
          imeiStock: true,
          qtyStock: true,
          repairModule: true,
          accessoriesModule: true,
          dealerIssueModule: false,
          reports: true,
          navigationStyle: false,
        );
    }
  }

  Future<void> _showRegenerateRecoveryCodeDialog() async {
    final currentPinController = TextEditingController();
    final authService = ref.read(localPinAuthServiceProvider);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Regenerate Recovery Code'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Enter current PIN to generate a new recovery code. The previous recovery code will stop working.',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentPinController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Current PIN',
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = currentPinController.text.trim();
                if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  AppNotifier.error('PIN must be 4 to 6 digits.');
                  return;
                }

                if (!mounted) {
                  return;
                }

                final pinNav = Navigator.of(dialogContext);
                pinNav.pop();

                final regenerated = await authService.regenerateRecoveryCode(
                  currentPin: pin,
                );

                if (regenerated == null) {
                  AppNotifier.error('Current PIN is incorrect.');
                  return;
                }

                await _showRecoveryCodeDialog(recoveryCode: regenerated);
                AppNotifier.success('Recovery code regenerated.');
              },
              child: const Text('Generate New Code'),
            ),
          ],
        );
      },
    );

    currentPinController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(backupSettingsProvider);
    final healthAsync = ref.watch(databaseHealthProvider);
    final startupHealthAsync = ref.watch(startupHealthFromSettingsProvider);
    final printQueue = ref.watch(invoicePrintQueueProvider);
    final authState = ref.watch(localPinAuthControllerProvider);
    final businessConfigAsync = ref.watch(businessConfigurationProvider);

    return Scaffold(
      body: AppLoadingOverlay(
        isLoading: _isProcessing,
        label: 'Processing...',
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ListView(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
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
                      const Text('Channel: ${AppRuntimeConfig.releaseChannel}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: businessConfigAsync.when(
                    data: (config) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Business Configuration',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Profile: ${config.profile.displayName}'),
                        Text('Source: ${config.source.name}'),
                        Text('Schema Version: ${config.schemaVersion}'),
                        const SizedBox(height: 12),
                        Text(
                          'Feature Flags',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: config.featureFlags.toMap().entries.map((e) {
                            final isEnabled = e.value == true;
                            return Chip(
                              label:
                                  Text('${e.key}: ${isEnabled ? "ON" : "OFF"}'),
                              backgroundColor: isEnabled
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Business Profile',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: BusinessProfile.values.map((profile) {
                            final isSelected = config.profile == profile;
                            return ChoiceChip(
                              label: Text(profile.displayName),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected && !mounted) return;
                                _changeBusinessProfile(profile);
                              },
                              selectedColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          config.profile.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(
                      height: 90,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 90,
                      child: Center(
                        child: Text('Failed to load business configuration.'),
                      ),
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
                        'Security',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authState.hasPinConfigured
                            ? 'Local PIN is required for login.'
                            : 'No PIN configured yet. Go to Login to set PIN.',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: authState.hasPinConfigured
                            ? _showChangePinDialog
                            : null,
                        icon: const Icon(Icons.password),
                        label: const Text('Change PIN'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: authState.hasPinConfigured
                            ? _showRegenerateRecoveryCodeDialog
                            : null,
                        icon: const Icon(Icons.key),
                        label: const Text('Regenerate Recovery Code'),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: authState.hasPinConfigured &&
                                authState.isAuthenticated
                            ? () {
                                ref
                                    .read(
                                        localPinAuthControllerProvider.notifier)
                                    .lock();
                                AppNotifier.info('App locked.');
                              }
                            : null,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Lock App'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shortcut: Ctrl+L',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
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
                          color: status.isHealthy
                              ? Theme.of(context).semantic.success
                              : Theme.of(context).semantic.warning,
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
                      child:
                          Center(child: Text('Failed to load startup health.')),
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
                          Text(
                              'Database size: ${_formatBytes(health.sizeBytes)}'),
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
                      child: Center(
                          child: Text('Failed to load database health.')),
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
                      Row(
                        children: <Widget>[
                          Text(
                            'Invoice Print Queue',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (printQueue.isNotEmpty)
                            Text(
                              '${printQueue.where((job) => job.status.canRetry).length} need attention',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (printQueue.isEmpty)
                        const Text('No queued or failed receipts.')
                      else
                        ...printQueue.map(
                          (job) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(job.invoiceNumber),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    AppStatusBadge(
                                      label: job.status.label,
                                      color: switch (job.status) {
                                        InvoicePrintJobStatus.pending =>
                                          Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        InvoicePrintJobStatus.processing =>
                                          Theme.of(context).semantic.info,
                                        InvoicePrintJobStatus.completed =>
                                          Theme.of(context).semantic.success,
                                        InvoicePrintJobStatus.failed =>
                                          Theme.of(context).semantic.warning,
                                        InvoicePrintJobStatus.cancelled =>
                                          Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                      },
                                    ),
                                    Text(
                                      'Retries: ${job.retryCount}/${PrintJobRepository.retryLimit}',
                                    ),
                                  ],
                                ),
                                Text(
                                  'Queued: ${FormattingHelpers.dateYmdHm(job.createdAt)} • '
                                  'Updated: ${FormattingHelpers.dateYmdHm(job.updatedAt)}',
                                ),
                                if (job.lastError != null)
                                  Text('Operator note: ${job.lastError}'),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Retry print',
                                  onPressed: !job.status.canRetry ||
                                          job.retryLimitReached
                                      ? null
                                      : () => _retryPrintJob(job),
                                  icon: const Icon(Icons.print_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Cancel queued receipt',
                                  onPressed: job.status ==
                                              InvoicePrintJobStatus
                                                  .processing ||
                                          job.status ==
                                              InvoicePrintJobStatus.completed ||
                                          job.status ==
                                              InvoicePrintJobStatus.cancelled
                                      ? null
                                      : () => _cancelPrintJob(job),
                                  icon: const Icon(Icons.cancel_outlined),
                                ),
                              ],
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
      return '${FormattingHelpers.decimal(kb)} KB';
    }
    final mb = kb / 1024;
    return '${FormattingHelpers.decimal(mb)} MB';
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppRuntimeConfig.appName,
      applicationVersion: AppRuntimeConfig.fullVersion,
      applicationLegalese: 'Developed by ${AppRuntimeConfig.developerName}',
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
