import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_pdf_renderer.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  const renderer = InvoicePdfRenderer();

  InvoicePrintDocument buildDocument() {
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
    );
  }

  bool hasPdfHeader(List<int> bytes) {
    if (bytes.length < 5) {
      return false;
    }
    return String.fromCharCodes(bytes.take(5)) == '%PDF-';
  }

  for (final size in InvoicePaperSize.values) {
    test('produces a valid PDF for ${size.label}', () async {
      final bytes = await renderer.build(
        document: buildDocument(),
        paperSize: size,
        shopProfile: const ShopProfile(
          shopName: 'Ali Mobiles',
          phone: '0300-1234567',
          email: '',
          address: 'Hall Road',
          footerNote: 'No returns after 7 days',
        ),
      );

      expect(bytes, isNotEmpty);
      expect(hasPdfHeader(bytes), isTrue);
    });
  }

  test('renders without a shop profile (falls back to document fields)',
      () async {
    final bytes = await renderer.build(
      document: buildDocument(),
      paperSize: InvoicePaperSize.a4,
    );

    expect(hasPdfHeader(bytes), isTrue);
  });
}
