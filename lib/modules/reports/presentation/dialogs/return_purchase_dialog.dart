import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

class ReturnPurchaseDialog extends ConsumerStatefulWidget {
  const ReturnPurchaseDialog({
    super.key,
    required this.purchaseId,
    required this.item,
  });

  final String purchaseId;
  final PurchaseHistoryItemEntity item;

  @override
  ConsumerState<ReturnPurchaseDialog> createState() =>
      _ReturnPurchaseDialogState();
}

class _ReturnPurchaseDialogState extends ConsumerState<ReturnPurchaseDialog> {
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _reasonController =
      TextEditingController(text: 'damage');
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.item.hasImei ? '1' : '';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Return Purchase Item'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Returning: ${widget.item.productName}'),
            if (widget.item.hasImei) Text('IMEI: ${widget.item.imei}'),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              decoration: InputDecoration(
                labelText: 'Quantity (max ${widget.item.returnableQty})',
              ),
              keyboardType: TextInputType.number,
              readOnly: widget.item.hasImei,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm Return'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final qty = widget.item.hasImei ? 1 : int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0 || qty > widget.item.returnableQty) {
      AppNotifier.error('Invalid return quantity.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppNotifier.error('Reason is required.');
      return;
    }

    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.processPurchaseReturn(
      purchaseId: widget.purchaseId,
      item: widget.item,
      quantity: qty,
      reason: reason,
      notes: _notesController.text,
    );

    if (!mounted) {
      return;
    }

    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }

    AppNotifier.success('Purchase return processed successfully.');
    ref.invalidate(purchaseHistoryRowsProvider);
    ref.invalidate(purchaseHistoryDetailProvider(widget.purchaseId));
    ref.invalidate(supplierLedgerSummaryProvider);
    ref.invalidate(supplierLedgerTimelineProvider);
    ref.invalidate(cashLedgerRowsProvider);
    Navigator.of(context).pop();
  }
}
