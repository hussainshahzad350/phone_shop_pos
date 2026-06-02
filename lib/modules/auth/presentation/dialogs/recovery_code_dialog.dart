import 'package:flutter/material.dart';

class RecoveryCodeDialog extends StatelessWidget {
  const RecoveryCodeDialog({
    super.key,
    required this.recoveryCode,
  });

  final String recoveryCode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Recovery Code'),
      content: SelectableText(
        'Store this code offline. You need it if you forget your PIN:\n\n'
        '$recoveryCode',
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I saved it'),
        ),
      ],
    );
  }
}
