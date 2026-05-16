import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';

typedef TrackSaleOperationAction =
    Future<Result<SaleCompletionEntity>> Function(
      Future<Result<SaleCompletionEntity>> Function() action,
    );
typedef CompleteSaleAction = Future<Result<SaleCompletionEntity>> Function();
typedef EnqueueInvoiceAction =
    Future<Result<String>> Function(InvoicePrintDocument document);
typedef ResetBillingAction = void Function();

class SaleCompletionFlow {
  const SaleCompletionFlow({
    required this.trackSaleOperation,
    required this.completeSale,
    required this.enqueueInvoice,
    required this.resetBilling,
  });

  final TrackSaleOperationAction trackSaleOperation;
  final CompleteSaleAction completeSale;
  final EnqueueInvoiceAction enqueueInvoice;
  final ResetBillingAction resetBilling;

  Future<SaleCompletionFlowOutcome> run({
    required BillingState billing,
    required List<CartItemEntity> saleItemsSnapshot,
  }) async {
    final completionResult = await trackSaleOperation(completeSale);
    if (completionResult.isFailure) {
      return SaleCompletionFlowOutcome(
        completionResult: completionResult,
        enqueueResult: null,
      );
    }

    final completion = completionResult.asSuccess!.value;
    final document = InvoicePrintDocument(
      saleId: completion.saleId,
      invoiceNumber: completion.invoiceNumber,
      saleDate: DateTime.now().toUtc(),
      items: saleItemsSnapshot,
      totals: completion.totals,
      paymentMethod: billing.paymentMethod,
      customerLabel:
          billing.selectedCustomerId == null ? 'Walk-in Customer' : 'Customer',
      notes: billing.notes.trim().isEmpty ? null : billing.notes.trim(),
    );
    final enqueueResult = await enqueueInvoice(document);

    resetBilling();
    return SaleCompletionFlowOutcome(
      completionResult: completionResult,
      enqueueResult: enqueueResult,
    );
  }
}

class SaleCompletionFlowOutcome {
  const SaleCompletionFlowOutcome({
    required this.completionResult,
    required this.enqueueResult,
  });

  final Result<SaleCompletionEntity> completionResult;
  final Result<String>? enqueueResult;
}
