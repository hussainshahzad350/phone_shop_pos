import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/services/recovery/email_recovery_service.dart';
import 'package:phone_shop_pos/core/services/recovery/recovery_providers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/auth/presentation/widgets/pin_input_field.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Recovery flow for when the owner has forgotten both the PIN and the recovery
/// code. A one-time code is emailed to the registered recovery address; once
/// verified, the PIN is reset (business data is untouched). On success the
/// dialog pops with the freshly issued recovery code.
class EmailRecoveryDialog extends ConsumerStatefulWidget {
  const EmailRecoveryDialog({super.key});

  @override
  ConsumerState<EmailRecoveryDialog> createState() =>
      _EmailRecoveryDialogState();
}

class _EmailRecoveryDialogState extends ConsumerState<EmailRecoveryDialog> {
  final _codeController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  String? _maskedEmail;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(emailRecoveryServiceProvider).requestResetCode();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (result.status == RecoveryRequestStatus.sent) {
        _codeSent = true;
        _maskedEmail = result.maskedEmail;
      } else if (result.status == RecoveryRequestStatus.noEmail) {
        _error = 'No recovery email is set on this device, so email reset is '
            'not available.';
      } else {
        _error = result.error ?? 'Could not send the code.';
      }
    });
  }

  Future<void> _verifyAndReset() async {
    if (_newPinController.text != _confirmPinController.text) {
      setState(() => _error = 'New PIN confirmation does not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(emailRecoveryServiceProvider).verifyAndResetPin(
              token: _codeController.text,
              newPin: _newPinController.text,
            );
    if (!mounted) {
      return;
    }
    if (result.status == RecoveryResetStatus.success) {
      Navigator.of(context).pop(result.newRecoveryCode);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error ?? 'Could not reset the PIN.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset PIN via email'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!_codeSent) ...<Widget>[
              const Text(
                'We will email a one-time code to your registered recovery '
                'address. Enter it on the next step to set a new PIN. Your '
                'shop data is not affected.',
              ),
            ] else ...<Widget>[
              Text(
                'Enter the code sent to ${_maskedEmail ?? 'your email'} and '
                'choose a new PIN.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                decoration: appDesktopInputDecoration(labelText: 'Email code'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              PinInputField(
                controller: _newPinController,
                labelText: 'New PIN',
              ),
              const SizedBox(height: 10),
              PinInputField(
                controller: _confirmPinController,
                labelText: 'Confirm New PIN',
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_codeSent)
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: Text(_busy ? 'Sending...' : 'Send code'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _verifyAndReset,
            child: Text(_busy ? 'Resetting...' : 'Verify & Reset'),
          ),
      ],
    );
  }
}
