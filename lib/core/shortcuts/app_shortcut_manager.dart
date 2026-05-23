import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/routing/navigation_leave_guard.dart';

enum AppShortcutEvent {
  focusSearch,
  focusPayment,
  refreshCurrentScreen,
  saveOrComplete,
}

class AppShortcutEventState {
  const AppShortcutEventState({
    this.event,
    this.token = 0,
  });

  final AppShortcutEvent? event;
  final int token;

  AppShortcutEventState copyWith({
    AppShortcutEvent? event,
    int? token,
  }) {
    return AppShortcutEventState(
      event: event ?? this.event,
      token: token ?? this.token,
    );
  }
}

class AppShortcutEventNotifier extends StateNotifier<AppShortcutEventState> {
  AppShortcutEventNotifier() : super(const AppShortcutEventState());

  void emit(AppShortcutEvent event) {
    state = state.copyWith(event: event, token: state.token + 1);
  }
}

final appShortcutEventBusProvider =
    StateNotifierProvider<AppShortcutEventNotifier, AppShortcutEventState>(
  (ref) => AppShortcutEventNotifier(),
);

class AppShortcutManager extends ConsumerWidget {
  const AppShortcutManager({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> guardedGo(String route) async {
      final currentPath = GoRouterState.of(context).uri.path;
      final shouldProceed = await confirmAndHandleCartLeave(
        context: context,
        ref: ref,
        currentPath: currentPath,
        targetPath: route,
      );
      if (!shouldProceed || !context.mounted) {
        return;
      }
      context.go(route);
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.f1): _FocusSearchIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
          ): _FocusSearchIntent(),
          SingleActivator(LogicalKeyboardKey.f2): _FocusPaymentIntent(),
          SingleActivator(LogicalKeyboardKey.f5): _RefreshIntent(),
          SingleActivator(LogicalKeyboardKey.f10): _SaveIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyB,
            control: true,
          ): _BackupIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyR,
            control: true,
          ): _ReportsIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyI,
            control: true,
          ): _InventoryIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
          ): _SalesIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
              onInvoke: (_) {
                ref
                    .read(appShortcutEventBusProvider.notifier)
                    .emit(AppShortcutEvent.focusSearch);
                return null;
              },
            ),
            _FocusPaymentIntent: CallbackAction<_FocusPaymentIntent>(
              onInvoke: (_) {
                ref
                    .read(appShortcutEventBusProvider.notifier)
                    .emit(AppShortcutEvent.focusPayment);
                return null;
              },
            ),
            _RefreshIntent: CallbackAction<_RefreshIntent>(
              onInvoke: (_) {
                ref
                    .read(appShortcutEventBusProvider.notifier)
                    .emit(AppShortcutEvent.refreshCurrentScreen);
                return null;
              },
            ),
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                ref
                    .read(appShortcutEventBusProvider.notifier)
                    .emit(AppShortcutEvent.saveOrComplete);
                return null;
              },
            ),
            _EscapeIntent: CallbackAction<_EscapeIntent>(
              onInvoke: (_) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
            _BackupIntent: CallbackAction<_BackupIntent>(
              onInvoke: (_) {
                guardedGo('/settings');
                AppNotifier.info(
                  'Ctrl+B opened Settings. Use One-Click Backup there to start backup.',
                );
                return null;
              },
            ),
            _ReportsIntent: CallbackAction<_ReportsIntent>(
              onInvoke: (_) {
                guardedGo('/reports');
                return null;
              },
            ),
            _InventoryIntent: CallbackAction<_InventoryIntent>(
              onInvoke: (_) {
                guardedGo('/inventory');
                return null;
              },
            ),
            _SalesIntent: CallbackAction<_SalesIntent>(
              onInvoke: (_) {
                guardedGo('/sales');
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _FocusPaymentIntent extends Intent {
  const _FocusPaymentIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _BackupIntent extends Intent {
  const _BackupIntent();
}

class _ReportsIntent extends Intent {
  const _ReportsIntent();
}

class _InventoryIntent extends Intent {
  const _InventoryIntent();
}

class _SalesIntent extends Intent {
  const _SalesIntent();
}
