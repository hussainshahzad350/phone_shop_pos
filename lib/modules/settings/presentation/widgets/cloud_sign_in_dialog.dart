import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/services/cloud/cloud_providers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

/// Signs the device into its cloud-backup account using an email one-time code.
/// Pops `true` once a session has been stored.
class CloudSignInDialog extends ConsumerStatefulWidget {
  const CloudSignInDialog({super.key});

  @override
  ConsumerState<CloudSignInDialog> createState() => _CloudSignInDialogState();
}

class _CloudSignInDialogState extends ConsumerState<CloudSignInDialog> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = await ref.read(cloudAuthServiceProvider.future);
    final result = await auth.requestCode(email);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (result.isSuccess) {
        _codeSent = true;
      } else {
        _error = result.asFailure!.error.message;
      }
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = await ref.read(cloudAuthServiceProvider.future);
    final result = await auth.signIn(
      email: _emailController.text.trim(),
      token: _codeController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.asFailure!.error.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in to Cloud Backup'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!_codeSent) ...<Widget>[
              const Text(
                'Enter your email. We will send a one-time code to confirm it. '
                'This signs this computer into your cloud backup account.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: appDesktopInputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ] else ...<Widget>[
              Text('Enter the code sent to ${_emailController.text.trim()}.'),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                decoration: appDesktopInputDecoration(labelText: 'Email code'),
                keyboardType: TextInputType.number,
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!_codeSent)
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: Text(_busy ? 'Sending...' : 'Send code'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: Text(_busy ? 'Signing in...' : 'Sign in'),
          ),
      ],
    );
  }
}
