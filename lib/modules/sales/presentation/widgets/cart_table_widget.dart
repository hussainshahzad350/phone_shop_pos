import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';

class CartTableWidget extends StatefulWidget {
  const CartTableWidget({
    super.key,
    required this.items,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onRemove,
    this.selectedIndex,
    this.onSelectRow,
  });

  final List<CartItemEntity> items;
  final ValueChanged<int> onIncreaseQty;
  final ValueChanged<int> onDecreaseQty;
  final ValueChanged<int> onRemove;
  final int? selectedIndex;
  final ValueChanged<int>? onSelectRow;

  @override
  State<CartTableWidget> createState() => _CartTableWidgetState();
}

class _CartTableWidgetState extends State<CartTableWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('Cart is empty'));
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _CartItemCard(
            item: item,
            selected: widget.selectedIndex == index,
            onTap: widget.onSelectRow == null
                ? null
                : () => widget.onSelectRow?.call(index),
            onIncreaseQty: () => widget.onIncreaseQty(index),
            onDecreaseQty: () => widget.onDecreaseQty(index),
            onRemove: () => widget.onRemove(index),
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onRemove,
  });

  final CartItemEntity item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onIncreaseQty;
  final VoidCallback onDecreaseQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: selected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.productName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.hasImei ? 'Serialized (IMEI)' : 'Quantity-based',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.hasImei
                                ? colorScheme.primary
                                : colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!item.hasImei) ...<Widget>[
                    _QtyStepper(
                      value: item.quantity,
                      onDecrease: onDecreaseQty,
                      onIncrease: onIncreaseQty,
                    ),
                  ] else ...<Widget>[
                    _CompactValueBox(
                      label: 'Qty',
                      value: '1',
                    ),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    FormattingHelpers.currencyPkr(item.lineTotal),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: colorScheme.error,
                    tooltip: 'Remove item',
                    onPressed: onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  _InfoChip(
                    label: 'IMEI',
                    value: _serializedLabel(item),
                  ),
                  _InfoChip(
                    label: 'Price',
                    value: FormattingHelpers.currencyPkr(item.unitPrice),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _serializedLabel(CartItemEntity item) {
    if (!item.hasImei) {
      return '-';
    }

    final parts = <String>[];
    if (item.imei?.trim().isNotEmpty == true) {
      parts.add(item.imei!.trim());
    }
    if (item.imei2?.trim().isNotEmpty == true) {
      parts.add(item.imei2!.trim());
    }

    final serial = item.serialNumber?.trim();
    final imeiText = parts.isEmpty ? '-' : parts.join(' / ');
    if (serial == null || serial.isEmpty) {
      return imeiText;
    }
    return '$imeiText [S/N: $serial]';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          '$label: $value',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CompactValueBox extends StatelessWidget {
  const _CompactValueBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrease,
            visualDensity: VisualDensity.compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrease,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
