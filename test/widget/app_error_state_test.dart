import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the message and a retry button that fires onRetry',
      (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        AppErrorState(
          message: 'Failed to load summary.',
          onRetry: () => retried++,
        ),
      ),
    );

    expect(find.text('Failed to load summary.'), findsOneWidget);

    final retry = find.widgetWithText(OutlinedButton, 'Retry');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retried, 1);
  });

  testWidgets('omits the retry button when onRetry is null', (tester) async {
    await tester.pumpWidget(
      wrap(const AppErrorState(message: 'Failed to load.')),
    );

    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('surfaces AppError.message as the detail line', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppErrorState(
          message: 'Failed to load.',
          error: AppError(code: 'db_locked', message: 'database is locked'),
        ),
      ),
    );

    expect(find.text('database is locked'), findsOneWidget);
  });
}
