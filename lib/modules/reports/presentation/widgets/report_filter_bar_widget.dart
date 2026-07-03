import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
    required this.onItemType,
    required this.onClear,
    this.customerOptionsError,
    this.productOptionsError,
    this.customerOptionsLoading = false,
    this.productOptionsLoading = false,
    this.onRetryCustomerOptions,
    this.onRetryProductOptions,
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
  final ValueChanged<String?> onItemType;
  final VoidCallback onClear;
  final String? customerOptionsError;
  final String? productOptionsError;
  final bool customerOptionsLoading;
  final bool productOptionsLoading;
  final VoidCallback? onRetryCustomerOptions;
  final VoidCallback? onRetryProductOptions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
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
                    filter.endDate == null
                        ? 'End Date'
                        : _displayDate(filter.endDate!),
                  ),
                ),
                _IdDropdown(
                  label: customerOptionsLoading
                      ? 'Customer (loading...)'
                      : 'Customer',
                  value: filter.customerId,
                  items: customerOptions,
                  onChanged: onCustomer,
                ),
                _IdDropdown(
                  label: productOptionsLoading
                      ? 'Product (loading...)'
                      : 'Product',
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
                  items: PaymentMethod.values,
                  onChanged: onPaymentMethod,
                  labelBuilder: (item) => PaymentMethod.labels[item] ?? item,
                ),
                _SimpleDropdown(
                  label: 'Item Type',
                  value: filter.itemType,
                  items: const <String>['phones', 'accessories'],
                  onChanged: onItemType,
                  labelBuilder: (item) =>
                      item == 'phones' ? 'Phones' : 'Accessories',
                ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                ),
              ],
            ),
            if (customerOptionsError != null ||
                productOptionsError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              if (customerOptionsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          customerOptionsError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: onRetryCustomerOptions,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (productOptionsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          productOptionsError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: onRetryProductOptions,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
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
    this.labelBuilder,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: appDesktopInputDecoration(labelText: label),
        onChanged: onChanged,
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          ...items.map(
            (item) => DropdownMenuItem<String?>(
              value: item,
              child: Text(labelBuilder?.call(item) ?? item),
            ),
          ),
        ],
      ),
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
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: appDesktopInputDecoration(labelText: label),
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
      ),
    );
  }
}
