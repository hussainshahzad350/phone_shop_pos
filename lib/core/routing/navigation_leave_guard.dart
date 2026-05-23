import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';

Future<bool> confirmAndHandleCartLeave({
  required BuildContext context,
  required WidgetRef ref,
  required String currentPath,
  required String targetPath,
}) async {
  final normalizedCurrentPath = _normalizePath(currentPath);
  final normalizedTargetPath = _normalizePath(targetPath);

  if (normalizedCurrentPath == normalizedTargetPath) {
    return false;
  }

  if (_isLeavingModule(
    currentPath: normalizedCurrentPath,
    targetPath: normalizedTargetPath,
    moduleRoot: '/sales',
  )) {
    final salesCartItems = ref.read(cartStateProvider);
    if (salesCartItems.isNotEmpty) {
      final shouldClear = await _showLeaveConfirmation(
        context: context,
        title: 'Clear sales cart?',
        message:
            'You have items in the Sales cart. If you leave this screen, the cart will be cleared.',
      );
      if (shouldClear != true) {
        return false;
      }
      ref.read(cartStateProvider.notifier).clearCart();
    }
  }

  if (!context.mounted) {
    return false;
  }

  if (_isLeavingModule(
    currentPath: normalizedCurrentPath,
    targetPath: normalizedTargetPath,
    moduleRoot: '/purchases',
  )) {
    final purchaseState = ref.read(purchaseFormStateProvider);
    if (purchaseState.items.isNotEmpty) {
      final shouldClear = await _showLeaveConfirmation(
        context: context,
        title: 'Clear purchase cart?',
        message:
            'You have items in the Purchase cart. If you leave this screen, the cart will be cleared.',
      );
      if (shouldClear != true) {
        return false;
      }
      ref.read(purchaseFormStateProvider.notifier).resetForm();
    }
  }

  return true;
}

bool _isLeavingModule({
  required String currentPath,
  required String targetPath,
  required String moduleRoot,
}) {
  return _isModulePath(currentPath, moduleRoot) &&
      !_isModulePath(targetPath, moduleRoot);
}

bool _isModulePath(String path, String moduleRoot) {
  return path == moduleRoot || path.startsWith('$moduleRoot/');
}

String _normalizePath(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '/';
  }
  final parsed = Uri.tryParse(trimmed);
  var path = parsed?.path ?? trimmed.split('?').first.split('#').first;
  if (path.isEmpty) {
    path = '/';
  }
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

Future<bool?> _showLeaveConfirmation({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave & Clear'),
        ),
      ],
    ),
  );
}
