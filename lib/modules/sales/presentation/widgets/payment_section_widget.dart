import 'package:flutter/material.dart';

class PaymentSectionWidget extends StatelessWidget {
  const PaymentSectionWidget({
    super.key,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onPaidAmountChanged,
    required this.onNotesChanged,
    required this.onCompleteSale,
    required this.isProcessing,
  });

  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onPaidAmountChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onCompleteSale;
  final bool isProcessing;

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
              value: paymentMethod,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'cash', child: Text('Cash')),
                DropdownMenuItem<String>(value: 'card', child: Text('Card')),
                DropdownMenuItem<String>(value: 'bank', child: Text('Bank Transfer')),
              ],
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Paid Amount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onPaidAmountChanged(double.tryParse(value) ?? 0),
            ),
            const SizedBox(height: 8),
            TextField(
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
                label: Text(isProcessing ? 'Processing...' : 'Complete Sale (F9)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
