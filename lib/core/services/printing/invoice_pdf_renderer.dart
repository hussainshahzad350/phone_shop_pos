import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';

/// Builds a printable / shareable PDF receipt from an [InvoicePrintDocument].
///
/// Mirrors the text [InvoicePrintRenderer] layout but produces a real PDF so a
/// receipt can be printed to a thermal or A4 printer, saved, and shared. Shop
/// identity is treated as live letterhead: the header prefers the current
/// [ShopProfile], falling back to the values snapshotted on the document.
class InvoicePdfRenderer {
  const InvoicePdfRenderer();

  /// Page geometry for each supported paper size. Thermal sizes use a roll
  /// format (fixed width, content-driven height); A4 uses a standard page.
  PdfPageFormat pageFormatFor(InvoicePaperSize size) {
    switch (size) {
      case InvoicePaperSize.thermal58:
        return const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        );
      case InvoicePaperSize.thermal80:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        );
      case InvoicePaperSize.a4:
        return PdfPageFormat.a4;
    }
  }

  Future<Uint8List> build({
    required InvoicePrintDocument document,
    required InvoicePaperSize paperSize,
    ShopProfile? shopProfile,
  }) async {
    final doc = pw.Document();
    final format = pageFormatFor(paperSize);
    final isRoll = paperSize != InvoicePaperSize.a4;
    final widgets = _content(
      document: document,
      shopProfile: shopProfile,
      compact: isRoll,
    );

    if (isRoll) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: widgets,
          ),
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (context) => widgets,
        ),
      );
    }

    return doc.save();
  }

  List<pw.Widget> _content({
    required InvoicePrintDocument document,
    required ShopProfile? shopProfile,
    required bool compact,
  }) {
    final baseSize = compact ? 8.0 : 10.0;
    final titleSize = compact ? 12.0 : 18.0;

    final storeName = _orFallback(shopProfile?.shopName, document.storeName);
    final contactLines = <String>[
      _orFallback(shopProfile?.phone, document.storeContactPhone),
      _orFallback(shopProfile?.email, document.storeContactEmail),
      _orFallback(shopProfile?.address, document.storeContactAddress),
    ].where((line) => line.trim().isNotEmpty).toList(growable: false);

    pw.Widget labelValue(String label, String value, {bool bold = false}) {
      final style = pw.TextStyle(
        fontSize: baseSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      );
    }

    final widgets = <pw.Widget>[
      pw.Center(
        child: pw.Text(
          storeName,
          style: pw.TextStyle(
            fontSize: titleSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      for (final line in contactLines)
        pw.Center(
          child: pw.Text(line, style: pw.TextStyle(fontSize: baseSize)),
        ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          document.invoiceNumber,
          style: pw.TextStyle(fontSize: baseSize, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Divider(thickness: 0.5),
      labelValue(
        'Date',
        FormattingHelpers.dateYmdHm(document.saleDate.toLocal()),
      ),
      labelValue('Payment', document.paymentMethod),
    ];

    final customerLabel = document.customerLabel?.trim();
    if (customerLabel != null && customerLabel.isNotEmpty) {
      widgets.add(labelValue('Customer', customerLabel));
    }
    final cashierName = document.cashierName?.trim();
    if (cashierName != null && cashierName.isNotEmpty) {
      widgets.add(labelValue('Cashier', cashierName));
    }

    widgets.add(pw.Divider(thickness: 0.5));

    for (final item in document.items) {
      widgets.add(
        pw.Text(
          item.productName,
          style: pw.TextStyle(fontSize: baseSize, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(
        labelValue(
          '${item.quantity} x ${FormattingHelpers.currencyPkr(item.unitPrice)}',
          FormattingHelpers.currencyPkr(item.lineTotal),
        ),
      );
      final imei = item.imei;
      if (imei != null && imei.isNotEmpty) {
        widgets.add(
          pw.Text('IMEI: $imei', style: pw.TextStyle(fontSize: baseSize)),
        );
      }
    }

    widgets.add(pw.Divider(thickness: 0.5));
    widgets.add(labelValue(
      'Subtotal',
      FormattingHelpers.currencyPkr(document.totals.subtotal),
    ));
    widgets.add(labelValue(
      'Discount',
      FormattingHelpers.currencyPkr(document.totals.discount),
    ));
    widgets.add(labelValue(
      'Tax',
      FormattingHelpers.currencyPkr(document.totals.tax),
    ));
    widgets.add(labelValue(
      'Total',
      FormattingHelpers.currencyPkr(document.totals.total),
      bold: true,
    ));
    widgets.add(labelValue(
      'Paid',
      FormattingHelpers.currencyPkr(document.totals.paidAmount),
    ));
    widgets.add(labelValue(
      'Balance',
      FormattingHelpers.currencyPkr(document.totals.remaining),
    ));

    final notes = NotesSafety.normalizeForRendering(document.notes);
    if (notes.isNotEmpty) {
      widgets.add(pw.Divider(thickness: 0.5));
      widgets.add(
        pw.Text('Notes:', style: pw.TextStyle(fontSize: baseSize, fontWeight: pw.FontWeight.bold)),
      );
      widgets.add(pw.Text(notes, style: pw.TextStyle(fontSize: baseSize)));
    }

    widgets.add(pw.Divider(thickness: 0.5));
    final footerNote = shopProfile?.footerNote?.trim();
    if (footerNote != null && footerNote.isNotEmpty) {
      widgets.add(
        pw.Center(
          child: pw.Text(footerNote, style: pw.TextStyle(fontSize: baseSize)),
        ),
      );
    }
    widgets.add(
      pw.Center(
        child: pw.Text(
          'Thank you for your purchase',
          style: pw.TextStyle(fontSize: baseSize),
        ),
      ),
    );

    return widgets;
  }

  String _orFallback(String? primary, String fallback) {
    final value = primary?.trim();
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }
}
