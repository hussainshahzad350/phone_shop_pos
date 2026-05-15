import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

class InvoicePrintRenderer {
  const InvoicePrintRenderer();

  String render({
    required InvoicePrintDocument document,
    required InvoicePaperSize paperSize,
  }) {
    final width = paperSize.charactersPerLine;
    final buffer = StringBuffer()
      ..writeln(_center(document.storeName, width))
      ..writeln(_center(document.invoiceNumber, width))
      ..writeln('-' * width)
      ..writeln('Date: ${FormattingHelpers.dateYmdHm(document.saleDate.toLocal())}')
      ..writeln('Payment: ${document.paymentMethod}');

    if (document.customerLabel != null && document.customerLabel!.trim().isNotEmpty) {
      buffer.writeln('Customer: ${document.customerLabel}');
    }
    if (document.cashierName != null && document.cashierName!.trim().isNotEmpty) {
      buffer.writeln('Cashier: ${document.cashierName}');
    }

    buffer.writeln('-' * width);

    for (final item in document.items) {
      final qtyText = '${item.quantity}x';
      final amount = FormattingHelpers.currencyPkr(item.lineTotal);
      final unitPrice = FormattingHelpers.currencyPkr(item.unitPrice);
      buffer
        ..writeln(_truncate(item.productName, width))
        ..writeln('$qtyText $unitPrice  $amount');
      if (item.imei != null && item.imei!.isNotEmpty) {
        buffer.writeln('IMEI: ${item.imei}');
      }
    }

    buffer
      ..writeln('-' * width)
      ..writeln('Subtotal: ${FormattingHelpers.currencyPkr(document.totals.subtotal)}')
      ..writeln('Discount: ${FormattingHelpers.currencyPkr(document.totals.discount)}')
      ..writeln('Tax: ${FormattingHelpers.currencyPkr(document.totals.tax)}')
      ..writeln('Total: ${FormattingHelpers.currencyPkr(document.totals.total)}')
      ..writeln('Paid: ${FormattingHelpers.currencyPkr(document.totals.paidAmount)}')
      ..writeln('Balance: ${FormattingHelpers.currencyPkr(document.totals.remaining)}');

    final trimmedNotes = document.notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      buffer
        ..writeln('-' * width)
        ..writeln('Notes:')
        ..writeln(_truncate(trimmedNotes, width));
    }

    buffer
      ..writeln('-' * width)
      ..writeln(_center('Thank you for your purchase', width));

    return buffer.toString();
  }

  String _center(String value, int width) {
    if (value.length >= width) {
      return value;
    }
    final padding = (width - value.length) ~/ 2;
    return '${' ' * padding}$value';
  }

  String _truncate(String value, int width) {
    if (value.length <= width) {
      return value;
    }
    if (width <= 3) {
      return value.substring(0, width);
    }
    return '${value.substring(0, width - 3)}...';
  }
}
