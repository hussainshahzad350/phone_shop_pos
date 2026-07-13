import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';

void main() {
  // Builds a PaymentSectionWidget with sensible defaults; individual tests
  // override only what they exercise and capture the relevant callbacks.
  Widget host({
    String paymentMethod = PaymentMethod.cash,
    double paidAmount = 0,
    String notes = '',
    bool isProcessing = false,
    bool canCompleteSale = true,
    String? disabledReason,
    ValueChanged<double>? onPaidAmountChanged,
    ValueChanged<String>? onNotesChanged,
    VoidCallback? onCompleteSale,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PaymentSectionWidget(
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          notes: notes,
          isProcessing: isProcessing,
          canCompleteSale: canCompleteSale,
          disabledReason: disabledReason,
          onPaymentMethodChanged: (_) {},
          onPaidAmountChanged: onPaidAmountChanged ?? (_) {},
          onNotesChanged: onNotesChanged ?? (_) {},
          onCompleteSale: onCompleteSale ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the payment controls and the current paid amount',
      (tester) async {
    await tester.pumpWidget(host(paidAmount: 1500, notes: 'urgent'));

    expect(find.text('Payment'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Paid Amount'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Notes'), findsOneWidget);
    expect(find.text('Complete Sale (F10)'), findsOneWidget);
    // Whole amounts render without a decimal tail.
    expect(find.text('1500'), findsOneWidget);
    expect(find.text('urgent'), findsOneWidget);
  });

  testWidgets('reports paid-amount and notes edits through callbacks',
      (tester) async {
    double? paid;
    String? notes;
    await tester.pumpWidget(host(
      onPaidAmountChanged: (value) => paid = value,
      onNotesChanged: (value) => notes = value,
    ));

    await tester.enterText(
      find.widgetWithText(TextField, 'Paid Amount'),
      '2000',
    );
    expect(paid, 2000);

    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'paid via cash',
    );
    expect(notes, 'paid via cash');
  });

  testWidgets('tapping Complete Sale fires the callback when enabled',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(host(onCompleteSale: () => completed += 1));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(completed, 1);
  });

  testWidgets('shows a processing state and blocks completion while processing',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(host(
      isProcessing: true,
      onCompleteSale: () => completed += 1,
    ));

    expect(find.text('Processing...'), findsOneWidget);
    expect(find.text('Complete Sale (F10)'), findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // The button is disabled while processing, so no completion is triggered.
    expect(completed, 0);
  });

  testWidgets('surfaces the disabled reason and blocks completion',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(host(
      canCompleteSale: false,
      disabledReason: 'Select a customer for a credit sale',
      onCompleteSale: () => completed += 1,
    ));

    expect(find.text('Select a customer for a credit sale'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(completed, 0);
  });
}
