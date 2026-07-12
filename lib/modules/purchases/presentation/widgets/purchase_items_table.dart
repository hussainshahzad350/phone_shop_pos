import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PurchaseItemsTable extends StatefulWidget {
  const PurchaseItemsTable({
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateUnitCost,
    required this.onUpdateImeiEntry,
    required this.onAddImeiEntries,
    required this.onRemoveImeiEntry,
    super.key,
  });

  final List<PurchaseFormItem> items;
  final void Function(int itemIndex) onRemoveItem;
  final void Function(int itemIndex, int quantity) onUpdateQuantity;
  final void Function(int itemIndex, double cost) onUpdateUnitCost;
  final void Function(int itemIndex, int imeiIndex, ImeiEntry entry)
      onUpdateImeiEntry;
  final void Function(int itemIndex) onAddImeiEntries;
  final void Function(int itemIndex, int imeiIndex) onRemoveImeiEntry;

  @override
  State<PurchaseItemsTable> createState() => _PurchaseItemsTableState();
}

class _PurchaseItemsTableState extends State<PurchaseItemsTable> {
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
        message: 'No items added. Search for a product to begin.',
        icon: Icons.inventory_2_outlined,
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
          return _PurchaseItemRow(
            item: item,
            itemIndex: index,
            onRemove: () => widget.onRemoveItem(index),
            onUpdateQuantity: (qty) => widget.onUpdateQuantity(index, qty),
            onUpdateUnitCost: (cost) => widget.onUpdateUnitCost(index, cost),
            onUpdateImeiEntry: (imeiIdx, entry) =>
                widget.onUpdateImeiEntry(index, imeiIdx, entry),
            onAddImeiEntries: () => widget.onAddImeiEntries(index),
            onRemoveImeiEntry: (imeiIdx) =>
                widget.onRemoveImeiEntry(index, imeiIdx),
          );
        },
      ),
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
    required this.onUpdateImeiEntry,
    required this.onAddImeiEntries,
    required this.onRemoveImeiEntry,
  });

  final PurchaseFormItem item;
  final int itemIndex;
  final VoidCallback onRemove;
  final void Function(int quantity) onUpdateQuantity;
  final void Function(double cost) onUpdateUnitCost;
  final void Function(int imeiIndex, ImeiEntry entry) onUpdateImeiEntry;
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
                          onEdit: (entry) => widget.onUpdateImeiEntry(i, entry),
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
    required this.onEdit,
    required this.onRemove,
  });

  final ImeiEntry entry;
  final int index;
  final ValueChanged<ImeiEntry> onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isUsed = entry.condition == SerializedStockCondition.used;
    final semantic = Theme.of(context).semantic;
    return Row(
      children: <Widget>[
        const SizedBox(width: 16),
        Text(
          '${index + 1}.',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        if (isUsed) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: semantic.warningContainer,
              borderRadius: AppRadii.xsRadius,
              border: Border.all(color: semantic.warning),
            ),
            child: Text(
              'Used',
              style: TextStyle(
                fontSize: 10,
                color: semantic.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _imeiDisplayText(),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        Text(
          FormattingHelpers.currencyPkr(entry.costPrice),
          style: const TextStyle(fontSize: 12),
        ),
        IconButton(
          iconSize: 16,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit IMEI',
          onPressed: () async {
            final updated = await showDialog<ImeiEntry>(
              context: context,
              builder: (context) => _EditImeiEntryDialog(entry: entry),
            );
            if (updated != null) {
              onEdit(updated);
            }
          },
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

  String _imeiDisplayText() {
    final imeiParts = <String>[entry.imei1.trim()];
    if (entry.imei2?.trim().isNotEmpty == true) {
      imeiParts.add(entry.imei2!.trim());
    }
    final serial = entry.serialNumber?.trim();
    if (serial == null || serial.isEmpty) {
      return imeiParts.join(' / ');
    }
    return '${imeiParts.join(' / ')} [S/N: $serial]';
  }
}

class _EditImeiEntryDialog extends StatefulWidget {
  const _EditImeiEntryDialog({required this.entry});

  final ImeiEntry entry;

  @override
  State<_EditImeiEntryDialog> createState() => _EditImeiEntryDialogState();
}

class _EditImeiEntryDialogState extends State<_EditImeiEntryDialog> {
  late final TextEditingController _imei1Controller;
  late final TextEditingController _imei2Controller;
  late final TextEditingController _serialController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;

  @override
  void initState() {
    super.initState();
    _imei1Controller = TextEditingController(text: widget.entry.imei1);
    _imei2Controller = TextEditingController(text: widget.entry.imei2 ?? '');
    _serialController =
        TextEditingController(text: widget.entry.serialNumber ?? '');
    _costController = TextEditingController(
      text: FormattingHelpers.decimal(widget.entry.costPrice),
    );
    _sellingController = TextEditingController(
      text: widget.entry.sellingPrice == null
          ? ''
          : FormattingHelpers.decimal(widget.entry.sellingPrice!),
    );
  }

  @override
  void dispose() {
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _serialController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit IMEI Entry'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _imei1Controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'IMEI 1',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _imei2Controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'IMEI 2',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serialController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Serial Number',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _costController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Cost Price',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sellingController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Sale Price',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final cost = FormattingHelpers.parseLocaleDecimal(
      _costController.text,
      fallback: -1,
    );
    final sellingText = _sellingController.text.trim();
    final sellingPrice = sellingText.isEmpty
        ? null
        : FormattingHelpers.parseLocaleDecimal(sellingText, fallback: -1);
    if (cost < 0 || (sellingPrice != null && sellingPrice < 0)) {
      return;
    }
    Navigator.of(context).pop(
      widget.entry.copyWith(
        imei1: _imei1Controller.text.trim(),
        imei2: _imei2Controller.text.trim(),
        clearImei2: _imei2Controller.text.trim().isEmpty,
        serialNumber: _serialController.text.trim(),
        clearSerialNumber: _serialController.text.trim().isEmpty,
        costPrice: cost,
        sellingPrice: sellingPrice,
        clearSellingPrice: sellingPrice == null,
      ),
    );
  }
}
