part of '../screens/repairing_screen.dart';

class _CollectPaymentRequest {
  const _CollectPaymentRequest({
    required this.amount,
    this.notes,
  });

  final double amount;
  final String? notes;
}

class _CollectPaymentDialog extends StatefulWidget {
  const _CollectPaymentDialog({required this.job});

  final RepairJobEntity job;

  @override
  State<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<_CollectPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.job.hasFinalPaymentAmount && widget.job.remainingPayment > 0) {
      _amountController.text = FormattingHelpers.decimal(
          widget.job.remainingPayment,
          fractionDigits: 0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    return FormattingHelpers.tryParseGroupedDecimalStrict(
      _amountController.text.trim(),
    );
  }

  void _submit() {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      AppNotifier.error('Enter a valid payment amount greater than zero.');
      return;
    }

    if (widget.job.hasFinalPaymentAmount &&
        amount > widget.job.remainingPayment + 0.009) {
      AppNotifier.error('Collected amount cannot exceed remaining payment.');
      return;
    }

    Navigator.of(context).pop(
      _CollectPaymentRequest(
        amount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final titleText = job.customerName?.trim().isNotEmpty == true
        ? job.customerName!
        : job.phoneModel;

    return AlertDialog(
      title: const Text('Collect Payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              titleText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Received so far: ${FormattingHelpers.currencyPkr(job.advanceReceived)}',
            ),
            Text(
              'Remaining: ${FormattingHelpers.currencyPkr(job.remainingPayment)}',
            ),
            if (job.hasFinalPaymentAmount)
              Text(
                'Final cost: ${FormattingHelpers.currencyPkr(job.finalCost ?? 0)}',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Amount to Collect',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Payment Notes (optional)',
                hintText: 'Cash, bank transfer, partial settlement…',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.payments_outlined, size: 16),
          label: const Text('Collect'),
        ),
      ],
    );
  }
}
