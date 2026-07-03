import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class InventoryFilterChips extends StatelessWidget {
  const InventoryFilterChips({
    super.key,
    required this.selectedStatus,
    required this.selectedHasImei,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  final SerializedStockStatus? selectedStatus;
  final bool? selectedHasImei;
  final ValueChanged<SerializedStockStatus?> onStatusChanged;
  final ValueChanged<bool?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        _buildLabel(context, 'Status:'),
        _statusChip(context, null, 'All Statuses'),
        _statusChip(context, SerializedStockStatus.inStock, 'In Stock'),
        _statusChip(context, SerializedStockStatus.sold, 'Sold'),
        _statusChip(context, SerializedStockStatus.reserved, 'Reserved'),
        const SizedBox(width: AppSpacing.sm),
        _buildLabel(context, 'Type:'),
        _typeChip(context, null, 'All'),
        _typeChip(context, true, 'Phones'),
        _typeChip(context, false, 'Accessories'),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _statusChip(
    BuildContext context,
    SerializedStockStatus? value,
    String label,
  ) {
    final selected = selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onStatusChanged(value),
    );
  }

  Widget _typeChip(BuildContext context, bool? value, String label) {
    final selected = selectedHasImei == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTypeChanged(value),
    );
  }
}
