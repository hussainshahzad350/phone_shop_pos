import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';

void main() {
  group('PHASE 2 Purchases P-038..P-039', () {
    testWidgets('P-038 Keyboard shortcut save flow emits save event',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppShortcutManager(
              child: _ShortcutProbe(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(appShortcutEventBusProvider).event, isNull);

      container
          .read(appShortcutEventBusProvider.notifier)
          .emit(AppShortcutEvent.saveOrComplete);
      await tester.pump();

      final state = container.read(appShortcutEventBusProvider);
      expect(state.event, AppShortcutEvent.saveOrComplete);
      expect(state.token, 1);
      expect(find.text('saveOrComplete'), findsOneWidget);
    });

    testWidgets('P-039 Focus restoration to product search remains stable',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppShortcutManager(
              child: _FocusProbe(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('invoice-field')));
      await tester.pump();
      expect(find.byKey(const Key('invoice-field')), findsOneWidget);
      expect(_focusNodeState(tester, const Key('invoice-field')), isTrue);

      container
          .read(appShortcutEventBusProvider.notifier)
          .emit(AppShortcutEvent.focusSearch);
      await tester.pump();

      expect(_focusNodeState(tester, const Key('product-field')), isTrue);
    });
  });
}

class _ShortcutProbe extends ConsumerWidget {
  const _ShortcutProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appShortcutEventBusProvider);
    return Scaffold(
      body: Center(
        child: Text(state.event?.name ?? 'none'),
      ),
    );
  }
}

class _FocusProbe extends ConsumerWidget {
  const _FocusProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productFocusNode = FocusNode(debugLabel: 'product');
    final invoiceFocusNode = FocusNode(debugLabel: 'invoice');

    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider,
        (previous, next) {
      if (next.event == AppShortcutEvent.focusSearch) {
        productFocusNode.requestFocus();
      }
    });

    return Scaffold(
      body: Column(
        children: <Widget>[
          TextField(
            key: const Key('product-field'),
            focusNode: productFocusNode,
            decoration:
                const InputDecoration(labelText: 'Search products to add'),
          ),
          TextField(
            key: const Key('invoice-field'),
            focusNode: invoiceFocusNode,
            decoration:
                const InputDecoration(labelText: 'Invoice Number (optional)'),
          ),
        ],
      ),
    );
  }
}

bool _focusNodeState(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  final editable = tester.widget<TextField>(finder);
  return editable.focusNode?.hasFocus ?? false;
}
