import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/tabs/purchase_history_tab.dart';

void main() {
  testWidgets('PurchaseHistoryTab renders rows without throwing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rows = <PurchaseHistoryRowEntity>[
      PurchaseHistoryRowEntity(
        purchaseId: 'p1',
        purchaseDate: DateTime(2026, 6, 28),
        supplierName: 'Demo Mobile Distributor',
        sellerName: 'Ali',
        invoiceNumber: 'PUR-001',
        total: 12000,
        paidAmount: 0,
        paymentMethod: 'cash',
        status: 'posted',
      ),
      PurchaseHistoryRowEntity(
        purchaseId: 'p2',
        purchaseDate: DateTime(2026, 6, 28),
        supplierName: 'Unknown Supplier',
        sellerName: null,
        invoiceNumber: null,
        total: 12000,
        paidAmount: 12000,
        paymentMethod: null,
        status: 'void',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          purchaseHistoryRowsProvider.overrideWith((ref) async => rows),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PurchaseHistoryTab(
              onOpenPurchaseDetail: (_) async {},
              onCancelPurchase: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo Mobile Distributor'), findsOneWidget);
    // Cancelled (void) purchase stays visible, labelled "Cancelled" not "Void".
    expect(find.text('Unknown Supplier'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Void'), findsNothing);
  });
}
