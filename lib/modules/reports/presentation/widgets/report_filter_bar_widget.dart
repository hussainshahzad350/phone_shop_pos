import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';

class ReportFilterBarWidget extends StatelessWidget {
  const ReportFilterBarWidget({
    super.key,
    required this.filter,
    required this.customerOptions,
    required this.productOptions,
    required this.onStartDate,
    required this.onEndDate,
    required this.onCustomer,
    required this.onProduct,
    required this.onStatus,
    required this.onPaymentMethod,
    required this.onClear,
  });

  final ReportFilterEntity filter;
  final List<MapEntry<String, String>> customerOptions;
  final List<MapEntry<String, String>> productOptions;
  final ValueChanged<DateTime?> onStartDate;
  final ValueChanged<DateTime?> onEndDate;
  final ValueChanged<String?> onCustomer;
  final ValueChanged<String?> onProduct;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onPaymentMethod;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(DateTime.now().year - 5),
              lastDate: DateTime(DateTime.now().year + 1),
              initialDate: filter.startDate ?? DateTime.now(),
            );
            onStartDate(picked);
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(
            filter.startDate == null
                ? 'Start Date'
                : _displayDate(filter.startDate!),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(DateTime.now().year - 5),
              lastDate: DateTime(DateTime.now().year + 1),
              initialDate: filter.endDate ?? DateTime.now(),
            );
            onEndDate(picked);
          },
          icon: const Icon(Icons.event),
          label: Text(
            filter.endDate == null ? 'End Date' : _displayDate(filter.endDate!),
          ),
        ),
        _IdDropdown(
          label: 'Customer',
          value: filter.customerId,
          items: customerOptions,
          onChanged: onCustomer,
        ),
        _IdDropdown(
          label: 'Product',
          value: filter.productModelId,
          items: productOptions,
          onChanged: onProduct,
        ),
        _SimpleDropdown(
          label: 'Status',
          value: filter.status,
          items: const <String>['paid', 'pending'],
          onChanged: onStatus,
        ),
        _SimpleDropdown(
          label: 'Payment',
          value: filter.paymentMethod,
          items: const <String>['cash', 'card', 'bank_transfer'],
          onChanged: onPaymentMethod,
        ),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear Filters'),
        ),
      ],
    );
  }

  String _displayDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _SimpleDropdown extends StatelessWidget {
  const _SimpleDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text(label),
      onChanged: onChanged,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        ...items.map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
    );
  }
}

class _IdDropdown extends StatelessWidget {
  const _IdDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<MapEntry<String, String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text(label),
      onChanged: onChanged,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        ...items.map(
          (item) => DropdownMenuItem<String?>(
            value: item.key,
            child: SizedBox(width: 180, child: Text(item.value)),
          ),
        ),
      ],
    );
  }
}
