import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_renderer.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  const renderer = InvoicePrintRenderer();

  InvoicePrintDocument buildDocument({String? notes}) {
    return InvoicePrintDocument(
      saleId: 'sal_1',
      invoiceNumber: 'INV-20260515-0001',
      saleDate: DateTime.utc(2026, 5, 15, 12, 0),
      items: const <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_1',
          productName: 'Samsung A54',
          hasImei: true,
          quantity: 1,
          unitPrice: 105000,
          imei: '356789101234561',
        ),
      ],
      totals: const SaleTotalsEntity(
        subtotal: 105000,
        discount: 0,
        tax: 0,
        total: 105000,
        paidAmount: 105000,
      ),
      paymentMethod: 'cash',
      customerLabel: 'Walk-in Customer',
      notes: notes,
    );
  }

  test('renders invoice headers and totals for thermal receipt', () {
    final output = renderer.render(
      document: buildDocument(),
      paperSize: InvoicePaperSize.thermal58,
    );

    expect(output, contains('INV-20260515-0001'));
    expect(output, contains('Samsung A54'));
    expect(output, contains('Total: PKR 105,000'));
    expect(output, contains('Thank you for your purchase'));
  });

  test('renders wider preview for A4 format', () {
    final output = renderer.render(
      document: buildDocument(),
      paperSize: InvoicePaperSize.a4,
    );

    final lines = output.split('\n');
    expect(lines.any((line) => line.length >= 60), isTrue);
  });

  test('renders live shop profile as the receipt header', () {
    const profile = ShopProfile(
      shopName: 'Ali Mobiles',
      phone: '0300-1234567',
      email: '',
      address: 'Hall Road',
      footerNote: 'No returns after 7 days',
    );

    final output = renderer.render(
      document: buildDocument(),
      paperSize: InvoicePaperSize.thermal80,
      shopProfile: profile,
    );

    expect(output, contains('Ali Mobiles'));
    expect(output, contains('0300-1234567'));
    expect(output, contains('Hall Road'));
    expect(output, contains('No returns after 7 days'));
    // Empty contact lines (email here) must not produce a blank header line.
    final headerLines = output.split('\n').take(4).toList();
    expect(headerLines.any((line) => line.trim().isEmpty), isFalse);
  });

  test('defensively renders notes as compact single-line text', () {
    final output = renderer.render(
      document: buildDocument(
        notes: '  line 1\nline 2\tline 3 ${'x' * 400}  ',
      ),
      paperSize: InvoicePaperSize.thermal58,
    );

    expect(output, contains('Notes:'));
    expect(output, isNot(contains('line 1\nline 2')));
  });
}
