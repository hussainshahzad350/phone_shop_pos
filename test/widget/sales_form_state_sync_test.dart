import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/customer_selector_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';

void main() {
  testWidgets(
      'payment section reflects latest riverpod-backed values on rebuild', (
    tester,
  ) async {
    String paymentMethod = 'cash';
    double paidAmount = 0;
    String notes = '';
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return PaymentSectionWidget(
                paymentMethod: paymentMethod,
                paidAmount: paidAmount,
                notes: notes,
                onPaymentMethodChanged: (value) {
                  setState(() => paymentMethod = value);
                },
                onPaidAmountChanged: (value) {
                  setState(() => paidAmount = value);
                },
                onNotesChanged: (value) {
                  setState(() => notes = value);
                },
                onCompleteSale: () {},
                isProcessing: false,
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'Paid Amount'), '2500');
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Notes'), 'Test note');
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card').last);
    await tester.pumpAndSettle();

    updateHost(() {
      paymentMethod = 'cash';
      paidAmount = 0;
      notes = '';
    });
    await tester.pump();

    expect(find.text('Card'), findsNothing);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('2500'), findsNothing);
    expect(find.text('Test note'), findsNothing);
  });

  testWidgets('paid amount field allows typing a fractional value', (
    tester,
  ) async {
    double paidAmount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PaymentSectionWidget(
                paymentMethod: 'cash',
                paidAmount: paidAmount,
                notes: '',
                onPaymentMethodChanged: (_) {},
                onPaidAmountChanged: (value) {
                  setState(() => paidAmount = value);
                },
                onNotesChanged: (_) {},
                onCompleteSale: () {},
                isProcessing: false,
              );
            },
          ),
        ),
      ),
    );

    final field = find.widgetWithText(TextField, 'Paid Amount');

    // Typing the decimal point must not be rewritten away by the controller
    // sync — otherwise a fractional amount can never be entered.
    await tester.enterText(field, '1250.');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '1250.');

    await tester.enterText(field, '1250.5');
    await tester.pump();
    expect(paidAmount, 1250.5);
    expect(tester.widget<TextField>(field).controller!.text, '1250.5');
  });

  testWidgets('customer selector picks a customer via the search field', (
    tester,
  ) async {
    String? selectedCustomerId;

    const customers = <CustomerOptionEntity>[
      CustomerOptionEntity(id: 'cus_1', name: 'Alice', phone: '0300'),
      CustomerOptionEntity(id: 'cus_2', name: 'Bob', phone: '0311'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CustomerSelectorWidget(
                customers: customers,
                selectedCustomerId: selectedCustomerId,
                onChanged: (value) {
                  setState(() => selectedCustomerId = value);
                },
              );
            },
          ),
        ),
      ),
    );

    // Open the floating results overlay and type directly into the field.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();

    expect(selectedCustomerId, 'cus_1');
    // Field now shows the selected customer and a ✕ to clear it.
    expect(find.textContaining('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets(
      'customer selector default dropdown list is limited to 5 customers', (
    tester,
  ) async {
    String? selectedCustomerId;

    final customers = List<CustomerOptionEntity>.generate(
      6,
      (index) => CustomerOptionEntity(
        id: 'cus_${index + 1}',
        name: 'Customer ${index + 1}',
        phone: '03${index + 1}00',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CustomerSelectorWidget(
                customers: customers,
                selectedCustomerId: selectedCustomerId,
                onChanged: (value) {
                  setState(() => selectedCustomerId = value);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(find.text('Walk-in Customer'), findsAtLeastNWidgets(1));
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 2', skipOffstage: false), findsOneWidget);
    expect(find.text('More...'), findsOneWidget);
    expect(
      find.text('Customer 6', skipOffstage: false),
      findsNothing,
    );

    await tester.tap(find.text('More...'));
    await tester.pumpAndSettle();

    // After "More...", all customers are present in the (scrollable) overlay
    // list; the last one may be scrolled offstage.
    expect(find.text('Customer 6', skipOffstage: false), findsOneWidget);
  });
}
