import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:phone_shop_pos/core/config/app_theme_mode.dart';
import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/config/theme_mode_provider.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_providers.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_storage_client.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/settings/presentation/providers/settings_providers.dart';
import 'package:phone_shop_pos/modules/settings/presentation/widgets/cloud_sign_in_dialog.dart';
import 'package:phone_shop_pos/shared/providers/core_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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

  Future<void> _showCloudSignInDialog() async {
    final signedIn = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const CloudSignInDialog(),
    );
    if (signedIn == true) {
      ref.invalidate(cloudSignedInProvider);
      ref.invalidate(cloudAccountEmailProvider);
      AppNotifier.success('Signed in to cloud backup.');
    }
  }

  Future<void> _cloudSignOut() async {
    final authService = await ref.read(cloudAuthServiceProvider.future);
    await authService.signOut();
    ref.invalidate(cloudSignedInProvider);
    ref.invalidate(cloudAccountEmailProvider);
    AppNotifier.info('Signed out of cloud backup.');
  }

  Future<void> _cloudBackupNow() async {
    setState(() => _isProcessing = true);
    final service = await ref.read(cloudBackupServiceProvider.future);
    final result = await ref
        .read(operationManagerProvider.notifier)
        .track<Result<CloudStorageObject>>(
          code: 'cloud_backup',
          label: 'Backing up to cloud',
          progressLabel: 'Uploading the backup to the cloud',
          action: (_) => service.backupNow(),
        );

    if (!mounted) {
      return;
    }
    setState(() => _isProcessing = false);
    if (result.isSuccess) {
      AppNotifier.success('Cloud backup complete: ${result.asSuccess!.value.name}');
    } else {
      AppNotifier.error(
        'Cloud backup failed: ${result.asFailure!.error.message}',
        action: SnackBarAction(label: 'Retry', onPressed: _cloudBackupNow),
      );
    }
  }

  Future<void> _showCloudRestoreDialog() async {
    setState(() => _isProcessing = true);
    final service = await ref.read(cloudBackupServiceProvider.future);
    final listResult = await service.listBackups();
    if (!mounted) {
      return;
    }
    setState(() => _isProcessing = false);
    if (listResult.isFailure) {
      AppNotifier.error(
        'Could not list cloud backups: ${listResult.asFailure!.error.message}',
      );
      return;
    }
    final backups = listResult.asSuccess!.value;
    if (backups.isEmpty) {
      AppNotifier.info('No cloud backups found yet.');
      return;
    }

    final selected = await showDialog<CloudStorageObject>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Restore from Cloud'),
          children: <Widget>[
            for (final backup in backups)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(backup),
                child: Text('${backup.name}  (${_formatBytes(backup.sizeBytes)})'),
              ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (selected == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AppConfirmationDialog(
        title: 'Restore from Cloud',
        message: 'Replace the live shop data with "${selected.name}"?\n\n'
            'Make a fresh backup first and ensure no one else is using the app.',
        confirmLabel: 'Restore',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);
    final result =
        await ref.read(operationManagerProvider.notifier).track<Result<void>>(
              code: 'cloud_restore',
              label: 'Restoring from cloud',
              progressLabel: 'Downloading and restoring the backup',
              action: (_) => service.restoreFromCloud(selected.name),
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
      AppNotifier.success('Restore from cloud completed successfully.');
    } else {
      AppNotifier.error('Restore failed: ${result.asFailure!.error.message}');
    }
  }

  Future<void> _showShopInfoDialog(ShopProfile current) async {
    final nameController = TextEditingController(text: current.shopName);
    final phoneController = TextEditingController(text: current.phone);
    final emailController = TextEditingController(text: current.email);
    final addressController = TextEditingController(text: current.address);
    final footerController =
        TextEditingController(text: current.footerNote ?? '');

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Edit Shop Information'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Shop name',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Phone',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: emailController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Email (optional)',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: addressController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Address',
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: footerController,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Receipt footer note (optional)',
                    hintText: 'e.g. No returns after 7 days',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  AppNotifier.error('Shop name is required.');
                  return;
                }
                final footer = footerController.text.trim();
                final updated = current.copyWith(
                  shopName: name,
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  address: addressController.text.trim(),
                  footerNote: footer.isEmpty ? null : footer,
                  clearFooterNote: footer.isEmpty,
                );
                final navigator = Navigator.of(dialogContext);
                try {
                  await ref.read(shopProfileProvider.notifier).save(updated);
                } catch (error) {
                  AppNotifier.error('Could not save shop information.');
                  return;
                }
                navigator.pop();
                AppNotifier.success('Shop information updated.');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    footerController.dispose();
  }

  Future<void> _showRecoveryEmailDialog(String? current) async {
    final controller = TextEditingController(text: current ?? '');
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recovery Email'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Enter the email used to reset your PIN if you forget both '
                  'your PIN and recovery code. Leave blank to remove it.',
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Recovery email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isNotEmpty &&
                    !LocalPinAuthController.isValidEmail(email)) {
                  AppNotifier.error('Enter a valid email or leave it blank.');
                  return;
                }
                final navigator = Navigator.of(dialogContext);
                final service = ref.read(localPinAuthServiceProvider);
                try {
                  if (email.isEmpty) {
                    await service.clearRecoveryEmail();
                  } else {
                    await service.setRecoveryEmail(email);
                  }
                } catch (_) {
                  AppNotifier.error('Could not save the recovery email.');
                  return;
                }
                ref.invalidate(recoveryEmailProvider);
                navigator.pop();
                AppNotifier.success(
                  email.isEmpty
                      ? 'Recovery email removed.'
                      : 'Recovery email saved.',
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
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
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.sm),
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

  Widget _buildAppearanceCard(BuildContext context) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final selected = themeModeAsync.asData?.value ?? AppThemeMode.system;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<AppThemeMode>(
              segments: <ButtonSegment<AppThemeMode>>[
                for (final mode in AppThemeMode.values)
                  ButtonSegment<AppThemeMode>(
                    value: mode,
                    label: Text(mode.displayName),
                    icon: Icon(_appearanceIcon(mode)),
                  ),
              ],
              selected: <AppThemeMode>{selected},
              showSelectedIcon: false,
              onSelectionChanged: themeModeAsync.isLoading
                  ? null
                  : (selection) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setMode(selection.first);
                    },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'System follows your operating system’s light or dark setting.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _appearanceIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(backupSettingsProvider);
    final healthAsync = ref.watch(databaseHealthProvider);
    final startupHealthAsync = ref.watch(startupHealthFromSettingsProvider);
    final authState = ref.watch(localPinAuthControllerProvider);
    final businessConfigAsync = ref.watch(businessConfigurationProvider);
    final recoveryEmail = ref.watch(recoveryEmailProvider).asData?.value;
    final cloudSignedIn = ref.watch(cloudSignedInProvider).asData?.value ?? false;
    final cloudEmail = ref.watch(cloudAccountEmailProvider).asData?.value;
    final shopProfile = ref.watch(shopProfileProvider);

    return Scaffold(
      body: AppLoadingOverlay(
        isLoading: _isProcessing,
        label: 'Processing...',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
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
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Deployment Metadata',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Version: ${AppRuntimeConfig.fullVersion}'),
                      const Text('Channel: ${AppRuntimeConfig.releaseChannel}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildAppearanceCard(context),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: businessConfigAsync.when(
                    data: (config) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Business Configuration',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Profile: ${config.profile.displayName}'),
                        Text('Source: ${config.source.name}'),
                        Text('Schema Version: ${config.schemaVersion}'),
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
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Shop Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _showShopInfoDialog(shopProfile),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Shop name: ${shopProfile.shopName}'),
                      Text(
                        'Phone: ${_orDash(shopProfile.phone)}',
                      ),
                      Text(
                        'Email: ${_orDash(shopProfile.email)}',
                      ),
                      Text(
                        'Address: ${_orDash(shopProfile.address)}',
                      ),
                      Text(
                        'Receipt footer: ${_orDash(shopProfile.footerNote ?? '')}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'These details appear on every printed and PDF receipt.',
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
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Security',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        authState.hasPinConfigured
                            ? 'Local PIN is required for login.'
                            : 'No PIN configured yet. Go to Login to set PIN.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: authState.hasPinConfigured
                            ? _showChangePinDialog
                            : null,
                        icon: const Icon(Icons.password),
                        label: const Text('Change PIN'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: authState.hasPinConfigured
                            ? _showRegenerateRecoveryCodeDialog
                            : null,
                        icon: const Icon(Icons.key),
                        label: const Text('Regenerate Recovery Code'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Recovery email: ${recoveryEmail ?? 'Not set'}'),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: authState.hasPinConfigured
                            ? () => _showRecoveryEmailDialog(recoveryEmail)
                            : null,
                        icon: const Icon(Icons.email_outlined),
                        label: Text(
                          recoveryEmail == null
                              ? 'Add Recovery Email'
                              : 'Change Recovery Email',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Used to reset your PIN by email if you forget both '
                        'your PIN and recovery code.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
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
                      const SizedBox(height: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: startupHealthAsync.when(
                    data: (status) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Startup Health',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppStatusBadge(
                          label: status.summary,
                          color: status.isHealthy
                              ? Theme.of(context).semantic.success
                              : Theme.of(context).semantic.warning,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('DB location: ${status.databasePath}'),
                        Text('Backup location: ${status.backupDirectoryPath}'),
                        Text(
                          'Checked: ${FormattingHelpers.dateYmdHm(status.checkedAt)}',
                        ),
                        if (status.warnings.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Backup & Restore',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Backup folder: ${settings.backupDirectoryPath ?? 'Default app backup folder'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Cloud Backup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!cloudSignedIn) ...<Widget>[
                        const Text(
                          'Sign in to keep an off-site copy of your shop data, '
                          'so you can recover it on another computer if this one '
                          'is lost or damaged.',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.tonalIcon(
                          onPressed: _isProcessing ? null : _showCloudSignInDialog,
                          icon: const Icon(Icons.cloud_outlined),
                          label: const Text('Sign in to Cloud Backup'),
                        ),
                      ] else ...<Widget>[
                        Text('Signed in as: ${cloudEmail ?? '—'}'),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: _isProcessing ? null : _cloudBackupNow,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Back up to Cloud now'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed:
                                  _isProcessing ? null : _showCloudRestoreDialog,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Restore from Cloud'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isProcessing ? null : _cloudSignOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign out'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.sm),
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
            ],
          ),
        ),
      ),
    );
  }

  String _orDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
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
