import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/product_management_providers.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/product_form_dialog.dart';

class ProductsPanel extends ConsumerStatefulWidget {
  const ProductsPanel({super.key});

  @override
  ConsumerState<ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends ConsumerState<ProductsPanel> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      ref.read(productManagementSearchQueryProvider.notifier).state = value;
    });
  }

  Future<List<String>> _loadBrandOptions() async {
    final repository = await ref.read(brandRepositoryProvider.future);
    final result = await repository.searchBrands(
      '',
      isActive: true,
      limit: 500,
    );
    if (result.isFailure) {
      return const <String>[];
    }
    final names = result.asSuccess!.value
        .map((brand) => brand.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<void> _createProduct() async {
    final brandOptions = await _loadBrandOptions();
    if (!mounted) {
      return;
    }
    final data = await showDialog<ProductFormData>(
      context: context,
      builder: (context) => ProductFormDialog(brandOptions: brandOptions),
    );
    if (data == null) {
      return;
    }
    final repository = await ref.read(productRepositoryProvider.future);
    if (data.sku != null) {
      final skuCheck = await repository.isSkuUnique(data.sku!);
      if (skuCheck.isFailure || skuCheck.asSuccess!.value == false) {
        AppNotifier.error('SKU must be unique.');
        return;
      }
    }

    final now = DateTime.now().toUtc();
    final result = await repository.createProduct(
      ProductEntity(
        id: '',
        name: data.name,
        brand: data.brand,
        category: data.category,
        sku: data.sku,
        barcode: data.barcode,
        minStockAlert: data.minStockAlert,
        purchasePrice: data.purchasePrice,
        salePrice: data.salePrice,
        hasImei: data.hasImei,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (result.isSuccess) {
      ref.invalidate(managedProductsProvider);
      AppNotifier.success('Product created.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _editProduct(ProductEntity product) async {
    final brandOptions = await _loadBrandOptions();
    if (!mounted) {
      return;
    }
    final data = await showDialog<ProductFormData>(
      context: context,
      builder: (context) =>
          ProductFormDialog(initial: product, brandOptions: brandOptions),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(productRepositoryProvider.future);
    if (data.sku != null) {
      final skuCheck = await repository.isSkuUnique(
        data.sku!,
        excludeId: product.id,
      );
      if (skuCheck.isFailure || skuCheck.asSuccess!.value == false) {
        AppNotifier.error('SKU must be unique.');
        return;
      }
    }

    final result = await repository.updateProduct(
      product.copyWith(
        name: data.name,
        brand: data.brand,
        category: data.category,
        sku: data.sku,
        barcode: data.barcode,
        minStockAlert: data.minStockAlert,
        purchasePrice: data.purchasePrice,
        salePrice: data.salePrice,
        hasImei: data.hasImei,
      ),
    );

    if (result.isSuccess) {
      ref.invalidate(managedProductsProvider);
      AppNotifier.success('Product updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(ProductEntity product) async {
    final isArchiving = product.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: isArchiving ? 'Archive Product' : 'Unarchive Product',
        message: isArchiving
            ? 'Archive ${product.name}?'
            : 'Unarchive ${product.name}?',
        confirmLabel: isArchiving ? 'Archive' : 'Unarchive',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final repository = await ref.read(productRepositoryProvider.future);
    final result = product.isActive
        ? await repository.deactivateProduct(product.id)
        : await repository.activateProduct(product.id);

    if (result.isSuccess) {
      ref.invalidate(managedProductsProvider);
      AppNotifier.info(
        product.isActive ? 'Product archived.' : 'Product re-activated.',
      );
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Widget _buildProductsTable(List<ProductEntity> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ProductsTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = _visibleColumns(layout);
        final columnWidths = _columnWidths(
          layout: layout,
          visibleColumns: visibleColumns,
          availableWidth: constraints.maxWidth,
        );

        return AppDataTable(
          showCheckboxColumn: false,
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns: visibleColumns
              .map((column) => _buildProductColumn(column, columnWidths))
              .toList(growable: false),
          rows: items.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final item = entry.value;
            return DataRow(
              cells: visibleColumns
                  .map(
                    (column) => _buildProductCell(
                      item,
                      rowNumber: rowIndex + 1,
                      column: column,
                      columnWidths: columnWidths,
                    ),
                  )
                  .toList(growable: false),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Map<_ProductsTableColumn, double> _columnWidths({
    required _ProductsTableLayout layout,
    required List<_ProductsTableColumn> visibleColumns,
    required double availableWidth,
  }) {
    final widths = <_ProductsTableColumn, double>{
      for (final column in visibleColumns) column: layout.baseWidth(column),
    };

    final baseWidth =
        widths.values.fold<double>(0, (sum, value) => sum + value);
    final spacingWidth = (visibleColumns.length - 1) * layout.columnSpacing;
    final extraWidth = availableWidth - baseWidth - spacingWidth - 24;

    if (extraWidth > 0) {
      const weightedColumns = <_ProductsTableColumn, int>{
        _ProductsTableColumn.name: 6,
        _ProductsTableColumn.brand: 3,
        _ProductsTableColumn.sku: 2,
        _ProductsTableColumn.buyPrice: 2,
        _ProductsTableColumn.sellPrice: 2,
      };
      final totalWeight = visibleColumns.fold<int>(
        0,
        (sum, column) => sum + (weightedColumns[column] ?? 0),
      );
      if (totalWeight > 0) {
        for (final column in visibleColumns) {
          final weight = weightedColumns[column] ?? 0;
          if (weight == 0) {
            continue;
          }
          widths[column] =
              widths[column]! + (extraWidth * weight / totalWeight);
        }
      }
    }

    return widths;
  }

  List<_ProductsTableColumn> _visibleColumns(_ProductsTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_ProductsTableColumn>[
        _ProductsTableColumn.sr,
        _ProductsTableColumn.name,
        _ProductsTableColumn.sellPrice,
        _ProductsTableColumn.buyPrice,
        _ProductsTableColumn.status,
        _ProductsTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_ProductsTableColumn>[
        _ProductsTableColumn.sr,
        _ProductsTableColumn.name,
        _ProductsTableColumn.brand,
        _ProductsTableColumn.buyPrice,
        _ProductsTableColumn.sellPrice,
        _ProductsTableColumn.type,
        _ProductsTableColumn.status,
        _ProductsTableColumn.actions,
      ];
    }
    return const <_ProductsTableColumn>[
      _ProductsTableColumn.sr,
      _ProductsTableColumn.name,
      _ProductsTableColumn.brand,
      _ProductsTableColumn.sku,
      _ProductsTableColumn.buyPrice,
      _ProductsTableColumn.sellPrice,
      _ProductsTableColumn.type,
      _ProductsTableColumn.status,
      _ProductsTableColumn.actions,
    ];
  }

  DataColumn _buildProductColumn(
    _ProductsTableColumn column,
    Map<_ProductsTableColumn, double> widths,
  ) {
    return DataColumn(
      numeric: false,
      label: _labelCell(_columnLabel(column), width: widths[column]!),
    );
  }

  DataCell _buildProductCell(
    ProductEntity item, {
    required int rowNumber,
    required _ProductsTableColumn column,
    required Map<_ProductsTableColumn, double> columnWidths,
  }) {
    switch (column) {
      case _ProductsTableColumn.sr:
        return DataCell(
          _textCell(
            rowNumber.toString(),
            width: columnWidths[column]!,
            textAlign: TextAlign.left,
          ),
        );
      case _ProductsTableColumn.name:
        return DataCell(_textCell(item.name, width: columnWidths[column]!));
      case _ProductsTableColumn.brand:
        return DataCell(
          _textCell(item.brand ?? '-', width: columnWidths[column]!),
        );
      case _ProductsTableColumn.sku:
        return DataCell(
          _textCell(item.sku ?? '-', width: columnWidths[column]!),
        );
      case _ProductsTableColumn.buyPrice:
        return DataCell(
          _textCell(
            _priceValue(item.purchasePrice),
            width: columnWidths[column]!,
            textAlign: TextAlign.left,
          ),
        );
      case _ProductsTableColumn.sellPrice:
        return DataCell(
          _textCell(
            _priceValue(item.salePrice),
            width: columnWidths[column]!,
            textAlign: TextAlign.left,
          ),
        );
      case _ProductsTableColumn.type:
        return DataCell(
          _textCell(item.hasImei ? 'IMEI' : 'Qty',
              width: columnWidths[column]!),
        );
      case _ProductsTableColumn.status:
        return DataCell(
            _statusCell(item.isActive, width: columnWidths[column]!));
      case _ProductsTableColumn.actions:
        return DataCell(
          SizedBox(
            width: columnWidths[column],
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Edit',
                  onPressed: () => _editProduct(item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: item.isActive ? 'Archive' : 'Unarchive',
                  onPressed: () => _toggleActive(item),
                  icon: Icon(
                    item.isActive
                        ? Icons.archive_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
    }
  }

  String _priceValue(double value) {
    return FormattingHelpers.decimal(value, fractionDigits: 0);
  }

  String _columnLabel(_ProductsTableColumn column) {
    switch (column) {
      case _ProductsTableColumn.sr:
        return 'SR#';
      case _ProductsTableColumn.name:
        return 'Name';
      case _ProductsTableColumn.brand:
        return 'Brand';
      case _ProductsTableColumn.sku:
        return 'SKU';
      case _ProductsTableColumn.buyPrice:
        return 'Buy Price (PKR)';
      case _ProductsTableColumn.sellPrice:
        return 'Sell Price (PKR)';
      case _ProductsTableColumn.type:
        return 'Type';
      case _ProductsTableColumn.status:
        return 'Status';
      case _ProductsTableColumn.actions:
        return 'Actions';
    }
  }

  Widget _labelCell(String label, {required double width}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _textCell(
    String value, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusCell(bool isActive, {required double width}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final fgColor = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isActive ? 'Active' : 'Archived',
            style: theme.textTheme.labelMedium?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final includeInactive = ref.watch(productManagementIncludeInactiveProvider);
    final productsAsync = ref.watch(managedProductsProvider);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search by name, SKU, barcode, brand...',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: includeInactive,
              label: const Text('Show inactive'),
              onSelected: (selected) {
                ref
                    .read(productManagementIncludeInactiveProvider.notifier)
                    .state = selected;
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _createProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: productsAsync.when(
                data: _buildProductsTable,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('Error loading products: $error'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(managedProductsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ProductsTableColumn {
  sr,
  name,
  brand,
  sku,
  buyPrice,
  sellPrice,
  type,
  status,
  actions,
}

class _ProductsTableLayout {
  const _ProductsTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.showMediumColumns,
    required this.showCompactColumns,
    required this.isWideDesktop,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showMediumColumns;
  final bool showCompactColumns;
  final bool isWideDesktop;

  factory _ProductsTableLayout.fromWidth(double width) {
    if (width >= 1600) {
      return const _ProductsTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1220) {
      return const _ProductsTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return const _ProductsTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }

  double baseWidth(_ProductsTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _ProductsTableColumn.sr:
          return 56;
        case _ProductsTableColumn.name:
          return 320;
        case _ProductsTableColumn.brand:
          return 170;
        case _ProductsTableColumn.sku:
          return 170;
        case _ProductsTableColumn.buyPrice:
          return 140;
        case _ProductsTableColumn.sellPrice:
          return 140;
        case _ProductsTableColumn.type:
          return 100;
        case _ProductsTableColumn.status:
          return 140;
        case _ProductsTableColumn.actions:
          return 140;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _ProductsTableColumn.sr:
          return 52;
        case _ProductsTableColumn.name:
          return 250;
        case _ProductsTableColumn.brand:
          return 145;
        case _ProductsTableColumn.sku:
          return 140;
        case _ProductsTableColumn.buyPrice:
          return 130;
        case _ProductsTableColumn.sellPrice:
          return 130;
        case _ProductsTableColumn.type:
          return 90;
        case _ProductsTableColumn.status:
          return 125;
        case _ProductsTableColumn.actions:
          return 132;
      }
    }
    switch (column) {
      case _ProductsTableColumn.sr:
        return 48;
      case _ProductsTableColumn.name:
        return 210;
      case _ProductsTableColumn.brand:
        return 120;
      case _ProductsTableColumn.sku:
        return 120;
      case _ProductsTableColumn.buyPrice:
      case _ProductsTableColumn.sellPrice:
        return 118;
      case _ProductsTableColumn.type:
        return 80;
      case _ProductsTableColumn.status:
        return 112;
      case _ProductsTableColumn.actions:
        return 128;
    }
  }
}
