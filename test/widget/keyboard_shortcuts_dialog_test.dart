import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/shortcuts/keyboard_shortcuts_dialog.dart';

void main() {
  testWidgets('shows grouped shortcuts with keys and descriptions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: KeyboardShortcutsDialog()),
      ),
    );

    expect(find.text('Keyboard Shortcuts'), findsOneWidget);

    // Group headers (rendered upper-cased).
    expect(find.text('NAVIGATION'), findsOneWidget);
    expect(find.text('SALES SCREEN'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);

    // A representative shortcut description and its keys.
    expect(find.text('Complete the sale'), findsOneWidget);
    expect(find.text('F10'), findsOneWidget);
    expect(find.text('Show this shortcuts help'), findsOneWidget);
  });

  testWidgets('Close button dismisses the dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => KeyboardShortcutsDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard Shortcuts'), findsNothing);
  });
}
