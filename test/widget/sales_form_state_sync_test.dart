import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/customer_selector_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';

void main() {
  testWidgets('payment section reflects latest riverpod-backed values on rebuild', (
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

    await tester.enterText(find.widgetWithText(TextField, 'Paid Amount'), '2500');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Test note');
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

  testWidgets('customer selector reflects latest selected customer and search text', (
    tester,
  ) async {
    String search = '';
    String? selectedCustomerId;
    late StateSetter updateHost;

    const customers = <CustomerOptionEntity>[
      CustomerOptionEntity(id: 'cus_1', name: 'Alice', phone: '0300'),
      CustomerOptionEntity(id: 'cus_2', name: 'Bob', phone: '0311'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return CustomerSelectorWidget(
                customers: customers,
                customerSearchQuery: search,
                selectedCustomerId: selectedCustomerId,
                onChanged: (value) {
                  setState(() => selectedCustomerId = value);
                },
                onSearchChanged: (value) {
                  setState(() => search = value);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search customer'),
      'Alice',
    );
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice (0300)').last);
    await tester.pumpAndSettle();

    updateHost(() {
      search = '';
      selectedCustomerId = null;
    });
    await tester.pump();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('Walk-in Customer'), findsOneWidget);
  });
}
