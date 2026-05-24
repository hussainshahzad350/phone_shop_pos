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

  Future<void> _createProduct() async {
    final data = await showDialog<ProductFormData>(
      context: context,
      builder: (context) => const ProductFormDialog(),
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
    final data = await showDialog<ProductFormData>(
      context: context,
      builder: (context) => ProductFormDialog(initial: product),
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
    final repository = await ref.read(productRepositoryProvider.future);
    final result = product.isActive
        ? await repository.deactivateProduct(product.id)
        : await repository.activateProduct(product.id);

    if (result.isSuccess) {
      ref.invalidate(managedProductsProvider);
      AppNotifier.info(
          product.isActive ? 'Product archived.' : 'Product re-activated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Widget _buildProductsTable(List<ProductEntity> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ProductsTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = _visibleColumns(layout);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns: visibleColumns
              .map((column) => _buildProductColumn(column, layout))
              .toList(growable: false),
          rows: items
              .map(
                (item) => DataRow(
                  cells: visibleColumns
                      .map((column) => _buildProductCell(item, column, layout))
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  List<_ProductsTableColumn> _visibleColumns(_ProductsTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_ProductsTableColumn>[
        _ProductsTableColumn.name,
        _ProductsTableColumn.price,
        _ProductsTableColumn.status,
        _ProductsTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_ProductsTableColumn>[
        _ProductsTableColumn.name,
        _ProductsTableColumn.brand,
        _ProductsTableColumn.price,
        _ProductsTableColumn.type,
        _ProductsTableColumn.status,
        _ProductsTableColumn.actions,
      ];
    }
    return const <_ProductsTableColumn>[
      _ProductsTableColumn.name,
      _ProductsTableColumn.brand,
      _ProductsTableColumn.sku,
      _ProductsTableColumn.price,
      _ProductsTableColumn.type,
      _ProductsTableColumn.status,
      _ProductsTableColumn.actions,
    ];
  }

  DataColumn _buildProductColumn(
    _ProductsTableColumn column,
    _ProductsTableLayout layout,
  ) {
    return DataColumn(
      label: _labelCell(_columnLabel(column), width: layout.valueWidth(column)),
    );
  }

  DataCell _buildProductCell(
    ProductEntity item,
    _ProductsTableColumn column,
    _ProductsTableLayout layout,
  ) {
    switch (column) {
      case _ProductsTableColumn.name:
        return DataCell(_textCell(item.name, width: layout.valueWidth(column)));
      case _ProductsTableColumn.brand:
        return DataCell(
          _textCell(item.brand ?? '-', width: layout.valueWidth(column)),
        );
      case _ProductsTableColumn.sku:
        return DataCell(
          _textCell(item.sku ?? '-', width: layout.valueWidth(column)),
        );
      case _ProductsTableColumn.price:
        return DataCell(
          _textCell(
            layout.showCompactColumns
                ? FormattingHelpers.currencyPkr(item.salePrice)
                : '${FormattingHelpers.currencyPkr(item.purchasePrice)} / ${FormattingHelpers.currencyPkr(item.salePrice)}',
            width: layout.valueWidth(column),
          ),
        );
      case _ProductsTableColumn.type:
        return DataCell(
          _textCell(item.hasImei ? 'IMEI' : 'Qty',
              width: layout.valueWidth(column)),
        );
      case _ProductsTableColumn.status:
        return DataCell(
          _textCell(
            item.isActive ? 'Active' : 'Archived',
            width: layout.valueWidth(column),
          ),
        );
      case _ProductsTableColumn.actions:
        return DataCell(
          SizedBox(
            width: layout.valueWidth(column),
            child: Wrap(
              spacing: 4,
              children: <Widget>[
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _editProduct(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: item.isActive ? 'Archive' : 'Activate',
                  onPressed: () => _toggleActive(item),
                  icon: Icon(
                    item.isActive
                        ? Icons.archive_outlined
                        : Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  String _columnLabel(_ProductsTableColumn column) {
    switch (column) {
      case _ProductsTableColumn.name:
        return 'Name';
      case _ProductsTableColumn.brand:
        return 'Brand';
      case _ProductsTableColumn.sku:
        return 'SKU';
      case _ProductsTableColumn.price:
        return 'Price';
      case _ProductsTableColumn.type:
        return 'Type';
      case _ProductsTableColumn.status:
        return 'Status';
      case _ProductsTableColumn.actions:
        return 'Actions';
    }
  }

  Widget _labelCell(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _textCell(String value, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.all(8),
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
  name,
  brand,
  sku,
  price,
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

  double valueWidth(_ProductsTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _ProductsTableColumn.name:
          return 320;
        case _ProductsTableColumn.brand:
          return 170;
        case _ProductsTableColumn.sku:
          return 170;
        case _ProductsTableColumn.price:
          return 230;
        case _ProductsTableColumn.type:
          return 100;
        case _ProductsTableColumn.status:
          return 120;
        case _ProductsTableColumn.actions:
          return 120;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _ProductsTableColumn.name:
          return 250;
        case _ProductsTableColumn.brand:
          return 145;
        case _ProductsTableColumn.sku:
          return 140;
        case _ProductsTableColumn.price:
          return 200;
        case _ProductsTableColumn.type:
          return 90;
        case _ProductsTableColumn.status:
          return 105;
        case _ProductsTableColumn.actions:
          return 110;
      }
    }
    switch (column) {
      case _ProductsTableColumn.name:
        return 220;
      case _ProductsTableColumn.brand:
        return 120;
      case _ProductsTableColumn.sku:
        return 120;
      case _ProductsTableColumn.price:
        return 145;
      case _ProductsTableColumn.type:
        return 80;
      case _ProductsTableColumn.status:
        return 95;
      case _ProductsTableColumn.actions:
        return 100;
    }
  }
}
