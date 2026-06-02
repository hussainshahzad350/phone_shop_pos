import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/modules/auth/presentation/dialogs/recovery_code_dialog.dart';
import 'package:phone_shop_pos/modules/auth/presentation/dialogs/reset_pin_dialog.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/auth/presentation/widgets/auth_card_shell.dart';
import 'package:phone_shop_pos/modules/auth/presentation/widgets/pin_input_field.dart';

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
  final _confirmPinFocus = FocusNode();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _recoveryCodeController.dispose();
    _newPinController.dispose();
    _newPinConfirmController.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final ctx = context;
    final authController = ref.read(localPinAuthControllerProvider.notifier);
    if (ref.read(localPinAuthControllerProvider).isBusy) return;
    final ok = await authController.loginWithPin(_pinController.text);
    if (!ok) return;
    if (!ctx.mounted) return;
    _pinController.clear();
    ctx.go('/dashboard');
  }

  Future<void> _doSetupPin() async {
    final ctx = context;
    final authController = ref.read(localPinAuthControllerProvider.notifier);
    if (ref.read(localPinAuthControllerProvider).isBusy) return;
    final recoveryCode = await authController.setupPin(
      pin: _pinController.text,
      confirmPin: _confirmPinController.text,
    );
    if (recoveryCode == null) return;
    if (!ctx.mounted) return;
    await _showRecoveryCodeDialog(
      context: ctx,
      recoveryCode: recoveryCode,
    );
    if (!ctx.mounted) return;
    _pinController.clear();
    _confirmPinController.clear();
    ctx.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(localPinAuthControllerProvider);

    return AuthCardShell(
      child: authState.isInitialized
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  authState.hasPinConfigured ? 'Enter PIN' : 'Set Local PIN',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  PinInputField(
                    controller: _pinController,
                    labelText: 'PIN',
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _doLogin(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: authState.isBusy ? null : _doLogin,
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
                  PinInputField(
                    controller: _pinController,
                    labelText: 'New PIN (4-6 digits)',
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_confirmPinFocus),
                  ),
                  const SizedBox(height: 10),
                  PinInputField(
                    controller: _confirmPinController,
                    labelText: 'Confirm PIN',
                    focusNode: _confirmPinFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _doSetupPin(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: authState.isBusy ? null : _doSetupPin,
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
    );
  }

  Future<void> _showRecoveryCodeDialog({
    required BuildContext context,
    required String recoveryCode,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecoveryCodeDialog(recoveryCode: recoveryCode),
    );
  }

  Future<void> _showForgotPinDialog(BuildContext context) async {
    _recoveryCodeController.clear();
    _newPinController.clear();
    _newPinConfirmController.clear();

    ref.read(localPinAuthControllerProvider.notifier).clearError();

    final didReset = await showDialog<bool>(
      context: context,
      builder: (context) => ResetPinDialog(
        recoveryCodeController: _recoveryCodeController,
        newPinController: _newPinController,
        newPinConfirmController: _newPinConfirmController,
      ),
    );

    if (!mounted || didReset != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN reset successful. Log in with new PIN.'),
      ),
    );
  }
}
