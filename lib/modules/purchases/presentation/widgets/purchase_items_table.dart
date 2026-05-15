import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

class PurchaseItemsTable extends StatelessWidget {
  const PurchaseItemsTable({
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateUnitCost,
    required this.onAddImeiEntries,
    required this.onRemoveImeiEntry,
    super.key,
  });

  final List<PurchaseFormItem> items;
  final void Function(int itemIndex) onRemoveItem;
  final void Function(int itemIndex, int quantity) onUpdateQuantity;
  final void Function(int itemIndex, double cost) onUpdateUnitCost;
  final void Function(int itemIndex) onAddImeiEntries;
  final void Function(int itemIndex, int imeiIndex) onRemoveImeiEntry;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No items added. Search for a product to begin.'),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _PurchaseItemRow(
          item: item,
          itemIndex: index,
          onRemove: () => onRemoveItem(index),
          onUpdateQuantity: (qty) => onUpdateQuantity(index, qty),
          onUpdateUnitCost: (cost) => onUpdateUnitCost(index, cost),
          onAddImeiEntries: () => onAddImeiEntries(index),
          onRemoveImeiEntry: (imeiIdx) => onRemoveImeiEntry(index, imeiIdx),
        );
      },
    );
  }
}

class _PurchaseItemRow extends StatefulWidget {
  const _PurchaseItemRow({
    required this.item,
    required this.itemIndex,
    required this.onRemove,
    required this.onUpdateQuantity,
    required this.onUpdateUnitCost,
    required this.onAddImeiEntries,
    required this.onRemoveImeiEntry,
  });

  final PurchaseFormItem item;
  final int itemIndex;
  final VoidCallback onRemove;
  final void Function(int quantity) onUpdateQuantity;
  final void Function(double cost) onUpdateUnitCost;
  final VoidCallback onAddImeiEntries;
  final void Function(int imeiIndex) onRemoveImeiEntry;

  @override
  State<_PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<_PurchaseItemRow> {
  late TextEditingController _qtyController;
  late TextEditingController _costController;
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _costFocus = FocusNode();
  bool _imeiExpanded = true;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _costController = TextEditingController(
      text: widget.item.unitCost.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(_PurchaseItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.item.hasImei) {
      if (!_qtyFocus.hasFocus) {
        final newQty = widget.item.quantity.toString();
        if (_qtyController.text != newQty) {
          _qtyController.text = newQty;
        }
      }
      if (!_costFocus.hasFocus) {
        final newCost = FormattingHelpers.decimal(widget.item.unitCost);
        if (_costController.text != newCost) {
          _costController.text = newCost;
        }
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _qtyFocus.dispose();
    _costFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.hasImei) ...<Widget>[
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _qtyController,
                      focusNode: _qtyFocus,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Qty',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (v) {
                        final qty = int.tryParse(v);
                        if (qty != null && qty > 0) {
                          widget.onUpdateQuantity(qty);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _costController,
                      focusNode: _costFocus,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Unit Cost',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final cost = FormattingHelpers.parseLocaleDecimal(
                          v,
                          fallback: -1,
                        );
                        if (cost >= 0) {
                          widget.onUpdateUnitCost(cost);
                        }
                      },
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    '${item.imeiEntries.length} device(s)',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(width: 16),
                Text(
                  FormattingHelpers.currencyPkr(item.lineTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.error,
                  tooltip: 'Remove item',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            if (item.hasImei) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: widget.onAddImeiEntries,
                    icon: const Icon(Icons.add),
                    label: const Text('Add IMEIs'),
                  ),
                  const SizedBox(width: 8),
                  if (item.imeiEntries.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _imeiExpanded = !_imeiExpanded;
                      }),
                      icon: Icon(
                        _imeiExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(
                        _imeiExpanded ? 'Collapse' : 'Show IMEIs',
                      ),
                    ),
                ],
              ),
              if (_imeiExpanded && item.imeiEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < item.imeiEntries.length; i++)
                        _ImeiEntryRow(
                          entry: item.imeiEntries[i],
                          index: i,
                          onRemove: () => widget.onRemoveImeiEntry(i),
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
}

class _ImeiEntryRow extends StatelessWidget {
  const _ImeiEntryRow({
    required this.entry,
    required this.index,
    required this.onRemove,
  });

  final ImeiEntry entry;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 16),
        Text(
          '${index + 1}.',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${entry.imei1}'
            '${entry.imei2 != null ? " / ${entry.imei2}" : ""}'
            '${entry.serialNumber != null ? " [${entry.serialNumber}]" : ""}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        Text(
          FormattingHelpers.currencyPkr(entry.costPrice),
          style: const TextStyle(fontSize: 12),
        ),
        IconButton(
          iconSize: 16,
          icon: const Icon(Icons.close),
          tooltip: 'Remove IMEI',
          onPressed: onRemove,
        ),
      ],
    );
  }
}
