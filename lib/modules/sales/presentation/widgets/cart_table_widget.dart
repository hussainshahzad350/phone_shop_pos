import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class CartTableWidget extends StatefulWidget {
  const CartTableWidget({
    super.key,
    required this.items,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onUpdateUnitPrice,
    required this.onRemove,
    this.selectedIndex,
    this.onSelectRow,
  });

  final List<CartItemEntity> items;
  final ValueChanged<int> onIncreaseQty;
  final ValueChanged<int> onDecreaseQty;
  final void Function(int index, double price) onUpdateUnitPrice;
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
      return const AppEmptyState(
        message: 'Cart is empty',
        icon: Icons.shopping_cart_outlined,
      );
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
            onUpdateUnitPrice: (price) =>
                widget.onUpdateUnitPrice(index, price),
            onRemove: () => widget.onRemove(index),
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatefulWidget {
  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onUpdateUnitPrice,
    required this.onRemove,
  });

  final CartItemEntity item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onIncreaseQty;
  final VoidCallback onDecreaseQty;
  final ValueChanged<double> onUpdateUnitPrice;
  final VoidCallback onRemove;

  @override
  State<_CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<_CartItemCard> {
  late final TextEditingController _priceController;
  final FocusNode _priceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: FormattingHelpers.decimal(widget.item.unitPrice),
    );
  }

  @override
  void didUpdateWidget(_CartItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_priceFocus.hasFocus &&
        oldWidget.item.unitPrice != widget.item.unitPrice) {
      _priceController.text = FormattingHelpers.decimal(widget.item.unitPrice);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: widget.selected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgRadius,
        side: BorderSide(
          color: widget.selected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: widget.selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadii.lgRadius,
        onTap: widget.onTap,
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
                      onDecrease: widget.onDecreaseQty,
                      onIncrease: widget.onIncreaseQty,
                    ),
                  ] else ...<Widget>[
                    const _CompactValueBox(
                      label: 'Qty',
                      value: '1',
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildPriceField(),
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
                    onPressed: widget.onRemove,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  if (item.hasImei)
                    _InfoChip(
                      label: 'IMEI',
                      value: _serializedLabel(item),
                    ),
                  if (item.purchaseDate != null)
                    _InfoChip(
                      label: 'Added On',
                      value: FormattingHelpers.dateYmd(item.purchaseDate!),
                    ),
                  if (item.supplierName != null &&
                      item.supplierName!.trim().isNotEmpty)
                    _InfoChip(
                      label: 'Supplier',
                      value: item.supplierName!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _priceController,
        focusNode: _priceFocus,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          labelText: 'Price',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(
            RegExp(r'[0-9., -]'),
          ),
        ],
        onChanged: (value) {
          final price = FormattingHelpers.parseLocaleDecimal(
            value,
            fallback: -1,
          );
          if (price >= 0) {
            widget.onUpdateUnitPrice(price);
          }
        },
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
        borderRadius: AppRadii.mdRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
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
        borderRadius: AppRadii.lgRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Decrease quantity',
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
            tooltip: 'Increase quantity',
            onPressed: onIncrease,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
