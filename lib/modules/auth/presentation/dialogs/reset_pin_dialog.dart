import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/auth/presentation/widgets/pin_input_field.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class ResetPinDialog extends ConsumerWidget {
  const ResetPinDialog({
    super.key,
    required this.recoveryCodeController,
    required this.newPinController,
    required this.newPinConfirmController,
  });

  final TextEditingController recoveryCodeController;
  final TextEditingController newPinController;
  final TextEditingController newPinConfirmController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(localPinAuthControllerProvider);
    final authController = ref.read(localPinAuthControllerProvider.notifier);

    return AlertDialog(
      title: const Text('Reset PIN with Recovery Code'),
      content: AppDialogContentBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: recoveryCodeController,
              decoration: appDesktopInputDecoration(
                labelText: 'Recovery Code',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            PinInputField(
              controller: newPinController,
              labelText: 'New PIN',
            ),
            const SizedBox(height: 10),
            PinInputField(
              controller: newPinConfirmController,
              labelText: 'Confirm New PIN',
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
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: authState.isBusy
              ? null
              : () async {
                  final ok = await authController.resetPinWithRecoveryCode(
                    recoveryCode: recoveryCodeController.text,
                    newPin: newPinController.text,
                    confirmPin: newPinConfirmController.text,
                  );
                  if (!context.mounted || !ok) {
                    return;
                  }
                  authController.clearError();
                  Navigator.of(context).pop(true);
                },
          child: const Text('Reset PIN'),
        ),
      ],
    );
  }
}
