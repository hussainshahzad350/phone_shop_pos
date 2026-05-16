import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/printer_service.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  test('writes printable payload to spool folder', () async {
    final temp = await Directory.systemTemp.createTemp('spool_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final service = FileSpoolPrinterService(spoolDirectoryPath: temp.path);
    final job = InvoicePrintJob(
      id: 'job_1',
      invoiceNumber: 'INV-1',
      createdAt: DateTime.utc(2026, 5, 15),
      updatedAt: DateTime.utc(2026, 5, 15),
      document: InvoicePrintDocument(
        saleId: 'sal_1',
        invoiceNumber: 'INV-1',
        saleDate: DateTime.utc(2026, 5, 15),
        items: <CartItemEntity>[],
        totals: const SaleTotalsEntity(
          subtotal: 0,
          discount: 0,
          tax: 0,
          total: 0,
          paidAmount: 0,
        ),
        paymentMethod: 'cash',
      ),
    );

    final result = await service.printInvoice(
      renderedPayload: 'sample receipt',
      job: job,
      paperSize: InvoicePaperSize.thermal80,
    );

    expect(result.isSuccess, isTrue);
    final path = result.asSuccess!.value.path;
    expect(File(path).existsSync(), isTrue);
  });
}
