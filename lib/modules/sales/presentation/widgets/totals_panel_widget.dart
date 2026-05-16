import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

class TotalsPanelWidget extends StatefulWidget {
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
  State<TotalsPanelWidget> createState() => _TotalsPanelWidgetState();
}

class _TotalsPanelWidgetState extends State<TotalsPanelWidget> {
  late final TextEditingController _discountController;
  late final TextEditingController _taxController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: _displayValue(widget.totals.discount),
    );
    _taxController = TextEditingController(
      text: _displayValue(widget.totals.tax),
    );
  }

  @override
  void didUpdateWidget(covariant TotalsPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllerWithState(_discountController, widget.totals.discount);
    _syncControllerWithState(_taxController, widget.totals.tax);
  }

  @override
  void dispose() {
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

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
            _line(label: 'Subtotal', value: widget.totals.subtotal),
            const SizedBox(height: 8),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => widget.onDiscountChanged(
                FormattingHelpers.parseLocaleDecimal(value),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _taxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tax',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => widget.onTaxChanged(
                FormattingHelpers.parseLocaleDecimal(value),
              ),
            ),
            const SizedBox(height: 8),
            _line(label: 'Total', value: widget.totals.total, bold: true),
            const SizedBox(height: 8),
            _line(label: 'Paid', value: widget.totals.paidAmount),
            const SizedBox(height: 8),
            _line(label: 'Remaining', value: widget.totals.remaining, bold: true),
          ],
        ),
      ),
    );
  }

  void _syncControllerWithState(TextEditingController controller, double value) {
    final parsed = FormattingHelpers.parseLocaleDecimal(controller.text);
    if ((parsed - value).abs() < 0.0001) {
      return;
    }
    final text = _displayValue(value);
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  String _displayValue(double value) {
    if (value == 0) {
      return '';
    }
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    final raw = FormattingHelpers.decimal(
      value,
      fractionDigits: 2,
      useGrouping: false,
    );
    return raw.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  Widget _line({required String label, required double value, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label),
        Text(
          FormattingHelpers.currencyPkr(value),
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}
