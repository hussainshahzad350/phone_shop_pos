import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PaymentSectionWidget extends StatefulWidget {
  const PaymentSectionWidget({
    super.key,
    required this.paymentMethod,
    required this.paidAmount,
    required this.notes,
    required this.onPaymentMethodChanged,
    required this.onPaidAmountChanged,
    required this.onNotesChanged,
    required this.onCompleteSale,
    this.onPaidAmountSubmitted,
    required this.isProcessing,
    this.canCompleteSale = true,
    this.disabledReason,
    this.paymentMethodFocusNode,
    this.paidAmountFocusNode,
    this.notesFocusNode,
  });

  final String paymentMethod;
  final double paidAmount;
  final String notes;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onPaidAmountChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onCompleteSale;
  final VoidCallback? onPaidAmountSubmitted;
  final bool isProcessing;
  final bool canCompleteSale;
  final String? disabledReason;
  final FocusNode? paymentMethodFocusNode;
  final FocusNode? paidAmountFocusNode;
  final FocusNode? notesFocusNode;

  @override
  State<PaymentSectionWidget> createState() => _PaymentSectionWidgetState();
}

class _PaymentSectionWidgetState extends State<PaymentSectionWidget> {
  static final RegExp _trimTrailingZeroPattern = RegExp(r'\.?0+$');

  late final TextEditingController _paidAmountController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _paidAmountController = TextEditingController(
      text: _displayAmount(widget.paidAmount),
    );
    _notesController = TextEditingController(text: widget.notes);
  }

  @override
  void didUpdateWidget(covariant PaymentSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(
      controller: _paidAmountController,
      nextText: _displayAmount(widget.paidAmount),
    );
    _syncController(
      controller: _notesController,
      nextText: widget.notes,
    );
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isProcessing || !widget.canCompleteSale;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Payment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              focusNode: widget.paymentMethodFocusNode,
              initialValue: widget.paymentMethod,
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
                  widget.onPaymentMethodChanged(value);
                }
              },
              decoration: appDesktopInputDecoration(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paidAmountController,
              focusNode: widget.paidAmountFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: appDesktopInputDecoration(labelText: 'Paid Amount'),
              onChanged: (value) => widget.onPaidAmountChanged(
                FormattingHelpers.parseLocaleDecimal(value),
              ),
              onSubmitted: (_) {
                if (widget.isProcessing) {
                  return;
                }
                (widget.onPaidAmountSubmitted ?? widget.onCompleteSale).call();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              focusNode: widget.notesFocusNode,
              maxLines: 2,
              maxLength: NotesSafety.maxLength,
              decoration: appDesktopInputDecoration(labelText: 'Notes'),
              onChanged: widget.onNotesChanged,
            ),
            const SizedBox(height: 12),
            if (!widget.canCompleteSale &&
                widget.disabledReason != null &&
                widget.disabledReason!.isNotEmpty) ...<Widget>[
              Text(
                widget.disabledReason!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isDisabled ? null : widget.onCompleteSale,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: Text(
                  widget.isProcessing ? 'Processing...' : 'Complete Sale (F10)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps controller text aligned with provider-backed widget values while
  /// preserving cursor placement and clearing stale IME composition state.
  void _syncController({
    required TextEditingController controller,
    required String nextText,
  }) {
    if (controller.text == nextText) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  String _displayAmount(double value) {
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
    return raw.replaceFirst(_trimTrailingZeroPattern, '');
  }
}
