import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  final _newPinController = TextEditingController();
  final _newPinConfirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _recoveryCodeController.dispose();
    _newPinController.dispose();
    _newPinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(localPinAuthControllerProvider);
    final authController = ref.read(localPinAuthControllerProvider.notifier);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: authState.isInitialized
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          authState.hasPinConfigured
                              ? 'Enter PIN'
                              : 'Set Local PIN',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${AppRuntimeConfig.appName} (Single-user mode)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (authState.hasPinConfigured) ...<Widget>[
                          TextField(
                            controller: _pinController,
                            decoration: appDesktopInputDecoration(
                              labelText: 'PIN',
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: authState.isBusy
                                      ? null
                                      : () async {
                                          final ok = await authController
                                              .loginWithPin(_pinController.text);
                                          if (!mounted || !ok) {
                                            return;
                                          }
                                          _pinController.clear();
                                          context.go('/dashboard');
                                        },
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('Login'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: authState.isBusy
                                ? null
                                : () => _showForgotPinDialog(context),
                            child: const Text('Forgot PIN?'),
                          ),
                        ] else ...<Widget>[
                          TextField(
                            controller: _pinController,
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
                            controller: _confirmPinController,
                            decoration: appDesktopInputDecoration(
                              labelText: 'Confirm PIN',
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: authState.isBusy
                                      ? null
                                      : () async {
                                          final recoveryCode =
                                              await authController.setupPin(
                                            pin: _pinController.text,
                                            confirmPin:
                                                _confirmPinController.text,
                                          );
                                          if (!mounted ||
                                              recoveryCode == null) {
                                            return;
                                          }
                                          await _showRecoveryCodeDialog(
                                            context: context,
                                            recoveryCode: recoveryCode,
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          _pinController.clear();
                                          _confirmPinController.clear();
                                          context.go('/dashboard');
                                        },
                                  icon: const Icon(Icons.verified_user),
                                  label: const Text('Save PIN and Continue'),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                    )
                  : const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoveryCodeDialog({
    required BuildContext context,
    required String recoveryCode,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save Recovery Code'),
        content: SelectableText(
          'Store this code offline. You need it if you forget your PIN:\n\n$recoveryCode',
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

  Future<void> _showForgotPinDialog(BuildContext context) async {
    _recoveryCodeController.clear();
    _newPinController.clear();
    _newPinConfirmController.clear();
    final authController = ref.read(localPinAuthControllerProvider.notifier);
    authController.clearError();
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final authState = dialogRef.watch(localPinAuthControllerProvider);
          return AlertDialog(
            title: const Text('Reset PIN with Recovery Code'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: _recoveryCodeController,
                    decoration: appDesktopInputDecoration(
                      labelText: 'Recovery Code',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPinController,
                    decoration: appDesktopInputDecoration(
                      labelText: 'New PIN',
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
                    controller: _newPinConfirmController,
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
                        final ok = await authController.resetPinWithRecoveryCode(
                          recoveryCode: _recoveryCodeController.text,
                          newPin: _newPinController.text,
                          confirmPin: _newPinConfirmController.text,
                        );
                        if (!mounted || !ok) {
                          return;
                        }
                        authController.clearError();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('PIN reset successful. Log in with new PIN.'),
                          ),
                        );
                      },
                child: const Text('Reset PIN'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
