import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';

class PaymentSectionWidget extends StatelessWidget {
  const PaymentSectionWidget({
    super.key,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onPaidAmountChanged,
    required this.onNotesChanged,
    required this.onCompleteSale,
    this.onPaidAmountSubmitted,
    required this.isProcessing,
    this.paymentMethodFocusNode,
    this.paidAmountFocusNode,
    this.notesFocusNode,
  });

  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onPaidAmountChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onCompleteSale;
  final VoidCallback? onPaidAmountSubmitted;
  final bool isProcessing;
  final FocusNode? paymentMethodFocusNode;
  final FocusNode? paidAmountFocusNode;
  final FocusNode? notesFocusNode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              focusNode: paymentMethodFocusNode,
              value: paymentMethod,
              items: PaymentMethod.values
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(PaymentMethod.labels[value] ?? value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onPaymentMethodChanged(value);
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              focusNode: paidAmountFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Paid Amount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onPaidAmountChanged(double.tryParse(value) ?? 0),
              onSubmitted: (_) {
                if (isProcessing) {
                  return;
                }
                (onPaidAmountSubmitted ?? onCompleteSale).call();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              focusNode: notesFocusNode,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onNotesChanged,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onCompleteSale,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: Text(isProcessing ? 'Processing...' : 'Complete Sale (F10)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
