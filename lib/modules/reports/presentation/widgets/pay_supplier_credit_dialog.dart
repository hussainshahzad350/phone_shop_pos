import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/user_facing_errors.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PaySupplierCreditDialog extends ConsumerStatefulWidget {
  const PaySupplierCreditDialog({
    super.key,
    required this.supplierId,
    this.maxAmount,
  });

  final String supplierId;
  final double? maxAmount;

  @override
  ConsumerState<PaySupplierCreditDialog> createState() =>
      _PaySupplierCreditDialogState();
}

class _PaySupplierCreditDialogState
    extends ConsumerState<PaySupplierCreditDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay Credit'),
      content: AppDialogContentBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.maxAmount != null && widget.maxAmount! > 0) ...<Widget>[
              Text(
                'Payable: ${FormattingHelpers.currencyPkr(widget.maxAmount!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              borderRadius: kAppDropdownMenuRadius,
              menuMaxHeight: kAppDropdownMenuMaxHeight,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Payment Method',
              ),
              items: PaymentMethod.values
                  .where((value) => value != PaymentMethod.credit)
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(PaymentMethod.labels[value]!),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Pay'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = FormattingHelpers.parseLocaleDecimal(_amountController.text);
    if (amount.isNaN || amount <= 0) {
      AppNotifier.error('Enter an amount greater than zero.');
      return;
    }
    final max = widget.maxAmount;
    if (max != null && max > 0 && amount > max + 0.009) {
      AppNotifier.error(UserFacingErrors.supplierOverpayment(maxPayable: max));
      return;
    }
    setState(() => _isSubmitting = true);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    final result = await service.paySupplierCredit(
      SupplierSettlementRequestPayload(
        supplierId: widget.supplierId,
        amount: amount,
        paymentMethod: _paymentMethod,
        note: _noteController.text,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success('Supplier credit paid.');
    Navigator.of(context).pop(true);
  }
}
