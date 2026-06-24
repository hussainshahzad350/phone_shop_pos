import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';

class DealerIssueMarkSoldDialog extends ConsumerStatefulWidget {
  const DealerIssueMarkSoldDialog({
    super.key,
    required this.issue,
  });

  final DealerIssueEntity issue;

  @override
  ConsumerState<DealerIssueMarkSoldDialog> createState() =>
      _DealerIssueMarkSoldDialogState();
}

class _DealerIssueMarkSoldDialogState
    extends ConsumerState<DealerIssueMarkSoldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  String _paymentMethod = 'cash';

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final salePrice = double.tryParse(_priceController.text.trim());
    if (salePrice == null || salePrice <= 0) return;

    final invoiceNumber = await ref
        .read(dealerIssueStateProvider.notifier)
        .markAsSoldViaDealer(
          issueId: widget.issue.issueId,
          salePrice: salePrice,
          paymentMethod: _paymentMethod,
        );

    if (mounted) {
      Navigator.of(context).pop(invoiceNumber != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      dealerIssueStateProvider.select((s) => s.isSubmitting),
    );
    final imeiCount = widget.issue.imeiList.length;

    return AlertDialog(
      title: const Text('Mark as Sold'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$imeiCount item${imeiCount == 1 ? '' : 's'} – Issue #${widget.issue.issueId.substring(0, 8)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sale Price (PKR)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter sale price';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'credit', child: Text('Credit (unpaid)')),
              ],
              onChanged: (value) {},
              onSaved: (value) {
                if (value != null) _paymentMethod = value;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: isSubmitting ? null : _submit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sell_outlined, size: 18),
          label: const Text('Record Sale'),
        ),
      ],
    );
  }
}

String dealerIssueSalePriceSummary(DealerIssueEntity issue) {
  if (issue.saleInvoiceId != null) {
    return 'Invoice: ${issue.saleInvoiceId}';
  }
  return '';
}
