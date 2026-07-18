import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_theme.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

void main() {
  const reason = 'Set final cost before delivery.';

  Widget harness({required bool touch, required bool enabled}) {
    return MaterialApp(
      theme: AppTheme.light(touch: touch),
      scaffoldMessengerKey: AppNotifier.messengerKey,
      home: Scaffold(
        body: Center(
          child: AppDisabledReasonTap(
            enabled: enabled,
            reason: reason,
            child: IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: enabled ? () {} : null,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('touch mode: tapping a disabled control surfaces the reason',
      (tester) async {
    await tester.pumpWidget(harness(touch: true, enabled: false));

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.textContaining(reason), findsOneWidget,
        reason: 'Touch users get the tooltip explanation as a snackbar');
  });

  testWidgets('touch mode: enabled controls are not wrapped', (tester) async {
    await tester.pumpWidget(harness(touch: true, enabled: true));

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.textContaining(reason), findsNothing);
  });

  testWidgets('desktop mode: disabled controls stay silent (tooltip only)',
      (tester) async {
    await tester.pumpWidget(harness(touch: false, enabled: false));

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.textContaining(reason), findsNothing,
        reason: 'Desktop keeps today\'s hover-tooltip behavior unchanged');
  });
}
