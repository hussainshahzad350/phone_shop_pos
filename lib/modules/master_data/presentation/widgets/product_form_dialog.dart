import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';

class ProductFormData {
  const ProductFormData({
    required this.name,
    required this.brand,
    required this.category,
    required this.sku,
    required this.barcode,
    required this.minStockAlert,
    required this.purchasePrice,
    required this.salePrice,
    required this.hasImei,
  });

  final String name;
  final String? brand;
  final String? category;
  final String? sku;
  final String? barcode;
  final int minStockAlert;
  final double purchasePrice;
  final double salePrice;
  final bool hasImei;
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.initial});

  final ProductEntity? initial;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _minStockController;
  late final TextEditingController _purchaseController;
  late final TextEditingController _saleController;

  final _nameFocus = FocusNode();
  final _brandFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _skuFocus = FocusNode();
  final _barcodeFocus = FocusNode();
  final _purchaseFocus = FocusNode();
  final _saleFocus = FocusNode();
  final _minStockFocus = FocusNode();

  late bool _hasImei;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _brandController = TextEditingController(text: initial?.brand ?? '');
    _categoryController = TextEditingController(text: initial?.category ?? '');
    _skuController = TextEditingController(text: initial?.sku ?? '');
    _barcodeController = TextEditingController(text: initial?.barcode ?? '');
    _minStockController =
        TextEditingController(text: (initial?.minStockAlert ?? 0).toString());
    _purchaseController = TextEditingController(
      text: FormattingHelpers.decimal(initial?.purchasePrice ?? 0),
    );
    _saleController = TextEditingController(
      text: FormattingHelpers.decimal(initial?.salePrice ?? 0),
    );
    _hasImei = initial?.hasImei ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _minStockController.dispose();
    _purchaseController.dispose();
    _saleController.dispose();
    _nameFocus.dispose();
    _brandFocus.dispose();
    _categoryFocus.dispose();
    _skuFocus.dispose();
    _barcodeFocus.dispose();
    _purchaseFocus.dispose();
    _saleFocus.dispose();
    _minStockFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final data = ProductFormData(
      name: _nameController.text.trim(),
      brand: _nullIfBlank(_brandController.text),
      category: _nullIfBlank(_categoryController.text),
      sku: _nullIfBlank(_skuController.text),
      barcode: _nullIfBlank(_barcodeController.text),
      minStockAlert:
          FormattingHelpers.parsePositiveInt(_minStockController.text) ?? 0,
      purchasePrice:
          FormattingHelpers.parseLocaleDecimal(_purchaseController.text),
      salePrice: FormattingHelpers.parseLocaleDecimal(_saleController.text),
      hasImei: _hasImei,
    );
    Navigator.of(context).pop(data);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _brandFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      focusNode: _brandFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _categoryFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      focusNode: _categoryFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _skuFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      focusNode: _skuFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _barcodeFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _purchaseFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _purchaseController,
                      focusNode: _purchaseFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _saleFocus.requestFocus(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) =>
                          FormattingHelpers.parseLocaleDecimal(value ?? '',
                                      fallback: -1) <
                                  0
                              ? 'Enter valid purchase price'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _saleController,
                      focusNode: _saleFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _minStockFocus.requestFocus(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Sale Price',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) =>
                          FormattingHelpers.parseLocaleDecimal(value ?? '',
                                      fallback: -1) <
                                  0
                              ? 'Enter valid sale price'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      focusNode: _minStockFocus,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Min Stock Alert',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      value: _hasImei,
                      title: const Text('Serialized (IMEI)'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _hasImei = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
