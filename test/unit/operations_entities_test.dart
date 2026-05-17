import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

void main() {
  test('sales history remaining balance is clamped at zero', () {
    final row = SalesHistoryRowEntity(
      saleId: 'sale-1',
      invoiceNumber: 'INV-1',
      saleDate: DateTime(2026, 1, 1),
      customerName: 'Customer',
      customerId: 'cust-1',
      total: 1000,
      paidAmount: 1200,
      paymentMethod: 'cash',
      printJobId: null,
    );

    expect(row.remainingBalance, 0);
    expect(row.isPaid, isTrue);
  });

  test('sales invoice item returnable quantity is clamped', () {
    const item = SalesInvoiceItemEntity(
      saleItemId: 'item-1',
      productModelId: 'prod-1',
      productName: 'Accessory',
      hasImei: false,
      quantity: 5,
      unitPrice: 100,
      lineTotal: 500,
      serializedStockId: null,
      imei: null,
      returnedQty: 7,
    );

    expect(item.returnableQty, 0);
  });
}
