import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
  const ProductFormDialog({
    super.key,
    this.initial,
    this.brandOptions = const <String>[],
  });

  final ProductEntity? initial;
  final List<String> brandOptions;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _minStockController;
  late final TextEditingController _purchaseController;
  late final TextEditingController _saleController;

  final _nameFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _skuFocus = FocusNode();
  final _barcodeFocus = FocusNode();
  final _purchaseFocus = FocusNode();
  final _saleFocus = FocusNode();
  final _minStockFocus = FocusNode();

  late bool _hasImei;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
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
    _selectedBrand = _normalizedBrandOrNull(initial?.brand);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _minStockController.dispose();
    _purchaseController.dispose();
    _saleController.dispose();
    _nameFocus.dispose();
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
      brand: _selectedBrand,
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

  String? _normalizedBrandOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    final availableBrands = widget.brandOptions
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_selectedBrand != null && !availableBrands.contains(_selectedBrand)) {
      availableBrands.add(_selectedBrand!);
    }

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
                onFieldSubmitted: (_) => _categoryFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  isDense: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownMenu<String?>(
                      initialSelection: _selectedBrand,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Brand'),
                      inputDecorationTheme: const InputDecorationTheme(
                        isDense: true,
                      ),
                      dropdownMenuEntries: <DropdownMenuEntry<String?>>[
                        const DropdownMenuEntry<String?>(
                          value: null,
                          label: '',
                        ),
                        ...availableBrands.map(
                          (brand) => DropdownMenuEntry<String?>(
                            value: brand,
                            label: brand,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        setState(() {
                          _selectedBrand = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      focusNode: _categoryFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _skuFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _purchaseFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.sm),
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
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
