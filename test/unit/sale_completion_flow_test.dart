import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/helpers/sale_completion_flow.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';

void main() {
  const totals = SaleTotalsEntity(
    subtotal: 1000,
    discount: 0,
    tax: 0,
    total: 1000,
    paidAmount: 1000,
  );
  const completion = SaleCompletionEntity(
    saleId: 'sale-1',
    invoiceNumber: 'INV-1',
    totals: totals,
  );
  const cartItems = <CartItemEntity>[
    CartItemEntity(
      productModelId: 'pm-1',
      productName: 'Phone A',
      hasImei: true,
      quantity: 1,
      unitPrice: 1000,
      serializedStockId: 'ss-1',
      imei: '111111111111111',
    ),
  ];
  final billing = BillingState(
    selectedCustomerId: 'cust-1',
    paymentMethod: 'cash',
    notes: 'done',
  );

  test('keeps completion success and queue success behavior', () async {
    var resetCount = 0;
    InvoicePrintDocument? capturedDocument;
    final flow = SaleCompletionFlow(
      trackSaleOperation: (action) => action(),
      completeSale: () async => const Success<SaleCompletionEntity>(completion),
      enqueueInvoice: (document) async {
        capturedDocument = document;
        return const Success<String>('job-1');
      },
      resetBilling: () => resetCount += 1,
    );

    final outcome = await flow.run(
      billing: billing,
      saleItemsSnapshot: cartItems,
    );

    expect(outcome.completionResult.isSuccess, isTrue);
    expect(outcome.enqueueResult?.isSuccess, isTrue);
    expect(outcome.enqueueResult?.asSuccess?.value, 'job-1');
    expect(capturedDocument?.invoiceNumber, 'INV-1');
    expect(resetCount, 1);
  });

  test('preserves success when enqueue fails and still resets billing',
      () async {
    var resetCount = 0;
    final flow = SaleCompletionFlow(
      trackSaleOperation: (action) => action(),
      completeSale: () async => const Success<SaleCompletionEntity>(completion),
      enqueueInvoice: (document) async => const Failure<String>(
        AppError(code: 'queue_error', message: 'queue failed'),
      ),
      resetBilling: () => resetCount += 1,
    );

    final outcome = await flow.run(
      billing: billing,
      saleItemsSnapshot: cartItems,
    );

    expect(outcome.completionResult.isSuccess, isTrue);
    expect(outcome.enqueueResult?.isFailure, isTrue);
    expect(resetCount, 1);
  });

  test('stops on completion failure without enqueue and without reset',
      () async {
    var resetCount = 0;
    var enqueueCount = 0;
    final flow = SaleCompletionFlow(
      trackSaleOperation: (action) => action(),
      completeSale: () async => const Failure<SaleCompletionEntity>(
        AppError(code: 'save_failed', message: 'failed'),
      ),
      enqueueInvoice: (document) async {
        enqueueCount += 1;
        return const Success<String>('unused');
      },
      resetBilling: () => resetCount += 1,
    );

    final outcome = await flow.run(
      billing: billing,
      saleItemsSnapshot: cartItems,
    );

    expect(outcome.completionResult.isFailure, isTrue);
    expect(outcome.enqueueResult, isNull);
    expect(enqueueCount, 0);
    expect(resetCount, 0);
  });
}
