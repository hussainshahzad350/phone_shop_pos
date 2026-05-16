import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';

const Map<ShortcutActivator, Intent> salesScreenShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowDown): CartNextIntent(),
  SingleActivator(LogicalKeyboardKey.arrowUp): CartPreviousIntent(),
  SingleActivator(LogicalKeyboardKey.delete): CartRemoveIntent(),
  SingleActivator(LogicalKeyboardKey.numpadAdd): CartIncreaseQtyIntent(),
  SingleActivator(LogicalKeyboardKey.equal): CartIncreaseQtyIntent(),
  SingleActivator(LogicalKeyboardKey.numpadSubtract): CartDecreaseQtyIntent(),
  SingleActivator(LogicalKeyboardKey.minus): CartDecreaseQtyIntent(),
  SingleActivator(LogicalKeyboardKey.escape): SalesEscapeIntent(),
};

class SalesGlobalShortcutHelper {
  const SalesGlobalShortcutHelper._();

  static int handle({
    required AppShortcutEventState state,
    required bool isMounted,
    required int handledShortcutToken,
    required VoidCallback onFocusSearch,
    required VoidCallback onFocusPayment,
    required VoidCallback onRefreshCurrentScreen,
    required VoidCallback onSaveOrComplete,
  }) {
    if (!isMounted || state.token == 0 || state.token == handledShortcutToken) {
      return handledShortcutToken;
    }

    switch (state.event) {
      case AppShortcutEvent.focusSearch:
        onFocusSearch();
        break;
      case AppShortcutEvent.focusPayment:
        onFocusPayment();
        break;
      case AppShortcutEvent.refreshCurrentScreen:
        onRefreshCurrentScreen();
        break;
      case AppShortcutEvent.saveOrComplete:
        onSaveOrComplete();
        break;
      case null:
        break;
    }

    return state.token;
  }
}

Map<Type, Action<Intent>> buildSalesScreenActions({
  required VoidCallback onCartNext,
  required VoidCallback onCartPrevious,
  required VoidCallback onIncreaseQty,
  required VoidCallback onDecreaseQty,
  required VoidCallback onRemove,
  required VoidCallback onEscape,
}) {
  return <Type, Action<Intent>>{
    CartNextIntent: CallbackAction<CartNextIntent>(
      onInvoke: (intent) {
        onCartNext();
        return null;
      },
    ),
    CartPreviousIntent: CallbackAction<CartPreviousIntent>(
      onInvoke: (intent) {
        onCartPrevious();
        return null;
      },
    ),
    CartIncreaseQtyIntent: CallbackAction<CartIncreaseQtyIntent>(
      onInvoke: (intent) {
        onIncreaseQty();
        return null;
      },
    ),
    CartDecreaseQtyIntent: CallbackAction<CartDecreaseQtyIntent>(
      onInvoke: (intent) {
        onDecreaseQty();
        return null;
      },
    ),
    CartRemoveIntent: CallbackAction<CartRemoveIntent>(
      onInvoke: (intent) {
        onRemove();
        return null;
      },
    ),
    SalesEscapeIntent: CallbackAction<SalesEscapeIntent>(
      onInvoke: (intent) {
        onEscape();
        return null;
      },
    ),
  };
}

class CartNextIntent extends Intent {
  const CartNextIntent();
}

class CartPreviousIntent extends Intent {
  const CartPreviousIntent();
}

class CartIncreaseQtyIntent extends Intent {
  const CartIncreaseQtyIntent();
}

class CartDecreaseQtyIntent extends Intent {
  const CartDecreaseQtyIntent();
}

class CartRemoveIntent extends Intent {
  const CartRemoveIntent();
}

class SalesEscapeIntent extends Intent {
  const SalesEscapeIntent();
}
