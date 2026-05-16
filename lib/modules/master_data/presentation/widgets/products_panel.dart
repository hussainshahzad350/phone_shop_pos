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
                data: (items) => AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Brand')),
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('Price')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(item.name)),
                            DataCell(Text(item.brand ?? '-')),
                            DataCell(Text(item.sku ?? '-')),
                            DataCell(Text(
                              '${FormattingHelpers.currencyPkr(item.purchasePrice)} / ${FormattingHelpers.currencyPkr(item.salePrice)}',
                            )),
                            DataCell(Text(item.hasImei ? 'IMEI' : 'Qty')),
                            DataCell(
                                Text(item.isActive ? 'Active' : 'Archived')),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _editProduct(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip:
                                        item.isActive ? 'Archive' : 'Activate',
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
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('Error loading products: $error'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(managedProductsProvider),
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
