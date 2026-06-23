import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';

void main() {
  testWidgets('action snackbars show a close icon and can be dismissed', (
    tester,
  ) async {
    addTearDown(() {
      AppNotifier.messengerKey.currentState?.clearSnackBars();
    });

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: AppNotifier.messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    AppNotifier.success(
      'Sale completed. Invoice: INV-1',
      action: SnackBarAction(label: 'Print Preview', onPressed: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Print Preview'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Sale completed. Invoice: INV-1'), findsNothing);
  });
}
