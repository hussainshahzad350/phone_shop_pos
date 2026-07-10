import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';

/// Editor opened by tapping a row in the inventory stock table.
///
/// A single row spans three data sources, so the dialog is context-aware:
/// - product-level fields (name, brand, category) → [ProductEntity]
/// - for a **serialized** row (a phone/IMEI unit): cost, selling price,
///   condition, buy date and notes → [SerializedStockEntity]
/// - for a **quantity** row (an accessory line): unit cost/price, min-stock and
///   location → [InventoryStockEntity]
///
/// Item type and IMEI are shown read-only (identity/structural), and serialized
/// status stays read-only here so it can only change through the proper
/// sales/return/reserve flows. Returns `true` when something was saved.
class StockItemEditDialog extends ConsumerStatefulWidget {
  const StockItemEditDialog({super.key, required this.row});

  final StockRowEntity row;

  @override
  ConsumerState<StockItemEditDialog> createState() =>
      _StockItemEditDialogState();
}

class _StockItemEditDialogState extends ConsumerState<StockItemEditDialog> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imeiController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _minStockController = TextEditingController();
  final _locationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  ProductEntity? _product;
  SerializedStockEntity? _unit;
  InventoryStockEntity? _stock;

  SerializedStockCondition _condition = SerializedStockCondition.newPhone;
  DateTime _buyDate = DateTime.now();

  bool get _isSerialized => widget.row.type == StockRowType.serialized;

  /// IMEI is a correctable typo only while the unit is still in stock; once it
  /// has been sold/reserved/returned/etc. the IMEI is locked as identity.
  bool get _canEditImei =>
      _isSerialized && _unit?.stockStatus == SerializedStockStatus.inStock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _imeiController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _minStockController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final productRepo = await ref.read(productRepositoryProvider.future);
      final inventoryRepo = await ref.read(inventoryRepositoryProvider.future);

      final productResult =
          await productRepo.getProductById(widget.row.productModelId);
      if (productResult.isFailure || productResult.asSuccess!.value == null) {
        _fail('Could not load the product for this item.');
        return;
      }
      _product = productResult.asSuccess!.value;

      if (_isSerialized) {
        final id = widget.row.serializedStockId;
        if (id == null) {
          _fail('This serialized item is missing its stock id.');
          return;
        }
        final unitResult = await inventoryRepo.getSerializedStockById(id);
        if (unitResult.isFailure || unitResult.asSuccess!.value == null) {
          _fail('Could not load this unit’s details.');
          return;
        }
        _unit = unitResult.asSuccess!.value;
        _condition = _unit!.condition;
        _buyDate = _unit!.createdAt.toLocal();
        _imeiController.text = _unit!.imei1;
        _costController.text = _money(_unit!.costPrice);
        _priceController.text =
            _unit!.sellingPrice == null ? '' : _money(_unit!.sellingPrice!);
        _notesController.text = _unit!.notes ?? '';
      } else {
        final stockResult = await inventoryRepo
            .getInventoryStockByProduct(widget.row.productModelId);
        if (stockResult.isFailure || stockResult.asSuccess!.value == null) {
          _fail('Could not load this item’s stock record.');
          return;
        }
        _stock = stockResult.asSuccess!.value;
        _costController.text = _money(_stock!.unitCost);
        _priceController.text = _money(_stock!.unitPrice);
        _minStockController.text = _stock!.minQuantity.toString();
        _locationController.text = _stock!.location ?? '';
      }

      _nameController.text = _product!.name;
      _brandController.text = _product!.brand ?? '';
      _categoryController.text = _product!.category ?? '';

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error) {
      _fail('Failed to load item details: $error');
    }
  }

  void _fail(String message) {
    if (mounted) {
      setState(() {
        _loading = false;
        _loadError = message;
      });
    }
  }

  String _money(double value) =>
      FormattingHelpers.decimal(value, fractionDigits: 0, useGrouping: false);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isSerialized ? 'Edit Phone' : 'Edit Accessory'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
                ? Text(_loadError!)
                : SingleChildScrollView(child: _buildForm(context)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_loading || _loadError != null || _saving) ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _readOnlyChips(context),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Item Name',
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isSerialized) ..._serializedFields(context) else ..._quantityFields(),
      ],
    );
  }

  Widget _readOnlyChips(BuildContext context) {
    final chips = <Widget>[
      Chip(
        avatar: Icon(_isSerialized ? Icons.smartphone : Icons.cable, size: 16),
        label: Text(_isSerialized ? 'Phone' : 'Accessory'),
        visualDensity: VisualDensity.compact,
      ),
    ];
    if (_isSerialized) {
      // When editable, the IMEI shows as its own field below instead of a chip.
      final imei = _unit?.imei1 ?? widget.row.imei1;
      if (!_canEditImei && imei != null && imei.isNotEmpty) {
        chips.add(Chip(
          label: Text('IMEI $imei'),
          visualDensity: VisualDensity.compact,
        ));
      }
      final status = widget.row.serializedStatus;
      if (status != null) {
        chips.add(Chip(
          label: Text('Status: ${_statusLabel(status)}'),
          visualDensity: VisualDensity.compact,
        ));
      }
    }
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: chips);
  }

  List<Widget> _serializedFields(BuildContext context) {
    return <Widget>[
      if (_canEditImei) ...<Widget>[
        TextField(
          controller: _imeiController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: const InputDecoration(
            labelText: 'IMEI',
            isDense: true,
            helperText: 'Correct a mis-typed IMEI (14–15 digits)',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Row(
        children: <Widget>[
          Expanded(child: _priceField(_costController, 'Cost Price')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _priceField(_priceController, 'Selling Price')),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<SerializedStockCondition>(
              initialValue: _condition,
              borderRadius: kAppDropdownMenuRadius,
              menuMaxHeight: kAppDropdownMenuMaxHeight,
              decoration: const InputDecoration(
                labelText: 'Condition',
                isDense: true,
              ),
              items: const <DropdownMenuItem<SerializedStockCondition>>[
                DropdownMenuItem<SerializedStockCondition>(
                  value: SerializedStockCondition.newPhone,
                  child: Text('New'),
                ),
                DropdownMenuItem<SerializedStockCondition>(
                  value: SerializedStockCondition.used,
                  child: Text('Used'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _condition = value);
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buyDateField(context)),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Notes',
          isDense: true,
        ),
      ),
    ];
  }

  List<Widget> _quantityFields() {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Quantity',
                isDense: true,
                helperText: 'Change via the stock adjustment (+/−) flow',
              ),
              child: Text(widget.row.quantity?.toString() ?? '0'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _minStockController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Min Stock',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(child: _priceField(_costController, 'Unit Cost')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _priceField(_priceController, 'Unit Price')),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _locationController,
        decoration: const InputDecoration(
          labelText: 'Location',
          isDense: true,
        ),
      ),
    ];
  }

  Widget _priceField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Widget _buyDateField(BuildContext context) {
    return InkWell(
      onTap: _pickBuyDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Buy Date',
          isDense: true,
          suffixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(FormattingHelpers.dateYmd(_buyDate)),
      ),
    );
  }

  Future<void> _pickBuyDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 10);
    final last = DateTime(now.year + 1);
    var initial = _buyDate;
    if (initial.isBefore(first)) {
      initial = first;
    } else if (initial.isAfter(last)) {
      initial = last;
    }
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: initial,
    );
    if (picked != null) {
      setState(() => _buyDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotifier.error('Item name is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      final productRepo = await ref.read(productRepositoryProvider.future);
      final inventoryRepo = await ref.read(inventoryRepositoryProvider.future);

      final nameCheck =
          await productRepo.isNameUnique(name, excludeId: _product!.id);
      if (nameCheck.isFailure || nameCheck.asSuccess!.value == false) {
        AppNotifier.error('A product named "$name" already exists.');
        _stopSaving();
        return;
      }

      final brand = _nullIfBlank(_brandController.text);
      final category = _nullIfBlank(_categoryController.text);
      final productUpdate = await productRepo.updateProduct(
        _product!.copyWith(
          name: name,
          brand: brand,
          category: category,
          clearBrand: brand == null,
          clearCategory: category == null,
        ),
      );
      if (productUpdate.isFailure) {
        AppNotifier.error(productUpdate.asFailure!.error.message);
        _stopSaving();
        return;
      }

      if (_isSerialized) {
        final unit = _unit!;
        final updated = SerializedStockEntity(
          id: unit.id,
          productModelId: unit.productModelId,
          imei1: _imeiController.text.trim(),
          imei2: unit.imei2,
          serialNumber: unit.serialNumber,
          stockStatus: unit.stockStatus,
          costPrice: FormattingHelpers.parseLocaleDecimal(_costController.text),
          // Store the chosen calendar day at local noon → UTC so it renders as
          // the same day back through dateYmd() regardless of timezone.
          createdAt:
              DateTime(_buyDate.year, _buyDate.month, _buyDate.day, 12).toUtc(),
          updatedAt: DateTime.now().toUtc(),
          sellingPrice: _nullableMoney(_priceController.text),
          supplierId: unit.supplierId,
          notes: _nullIfBlank(_notesController.text),
          condition: _condition,
          sellerName: unit.sellerName,
          sellerIdCard: unit.sellerIdCard,
          sellerAddress: unit.sellerAddress,
          remainingWarranty: unit.remainingWarranty,
          accessories: unit.accessories,
          phoneConditionNotes: unit.phoneConditionNotes,
          sellerPhone: unit.sellerPhone,
        );
        final result = await inventoryRepo.updateSerializedStock(updated);
        if (result.isFailure) {
          AppNotifier.error(result.asFailure!.error.message);
          _stopSaving();
          return;
        }
      } else {
        final stock = _stock!;
        final updated = InventoryStockEntity(
          id: stock.id,
          productModelId: stock.productModelId,
          quantity: stock.quantity,
          minQuantity: FormattingHelpers.parsePositiveInt(
                _minStockController.text,
              ) ??
              stock.minQuantity,
          maxQuantity: stock.maxQuantity,
          unitCost: FormattingHelpers.parseLocaleDecimal(_costController.text),
          unitPrice: FormattingHelpers.parseLocaleDecimal(_priceController.text),
          location: _nullIfBlank(_locationController.text),
          createdAt: stock.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
        final result = await inventoryRepo.upsertInventoryStock(updated);
        if (result.isFailure) {
          AppNotifier.error(result.asFailure!.error.message);
          _stopSaving();
          return;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      AppNotifier.error('Failed to save changes: $error');
      _stopSaving();
    }
  }

  void _stopSaving() {
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  double? _nullableMoney(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return FormattingHelpers.parseLocaleDecimal(trimmed);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _statusLabel(SerializedStockStatus status) {
    switch (status) {
      case SerializedStockStatus.inStock:
        return 'In Stock';
      case SerializedStockStatus.sold:
        return 'Sold';
      case SerializedStockStatus.reserved:
        return 'Reserved';
      case SerializedStockStatus.returned:
        return 'Returned';
      case SerializedStockStatus.damaged:
        return 'Damaged';
      case SerializedStockStatus.withDealer:
        return 'With Dealer';
    }
  }
}
