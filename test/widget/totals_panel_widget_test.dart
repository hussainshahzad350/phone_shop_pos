import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/totals_panel_widget.dart';

void main() {
  testWidgets('totals panel preserves discount and tax values across rebuilds', (
    tester,
  ) async {
    double discount = 0;
    double tax = 0;
    var rebuildVersion = 0;
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return KeyedSubtree(
                key: ValueKey<int>(rebuildVersion),
                child: TotalsPanelWidget(
                  totals: SaleTotalsEntity(
                    subtotal: 1000,
                    discount: discount,
                    tax: tax,
                    total: 1000 - discount + tax,
                    paidAmount: 0,
                  ),
                  onDiscountChanged: (value) {
                    setState(() => discount = value);
                  },
                  onTaxChanged: (value) {
                    setState(() => tax = value);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Discount'),
      '12.5',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tax'),
      '3',
    );
    await tester.pump();

    updateHost(() => rebuildVersion += 1);
    await tester.pump();

    expect(find.text('12.5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(discount, 12.5);
    expect(tax, 3);
  });
}
