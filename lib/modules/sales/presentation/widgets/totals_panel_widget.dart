import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

class TotalsPanelWidget extends StatelessWidget {
  const TotalsPanelWidget({
    super.key,
    required this.totals,
    required this.onDiscountChanged,
    required this.onTaxChanged,
  });

  final SaleTotalsEntity totals;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<double> onTaxChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Totals', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _line(label: 'Subtotal', value: totals.subtotal),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onDiscountChanged(double.tryParse(value) ?? 0),
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tax',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onTaxChanged(double.tryParse(value) ?? 0),
            ),
            const SizedBox(height: 8),
            _line(label: 'Total', value: totals.total, bold: true),
            const SizedBox(height: 8),
            _line(label: 'Paid', value: totals.paidAmount),
            const SizedBox(height: 8),
            _line(label: 'Remaining', value: totals.remaining, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _line({required String label, required double value, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}
