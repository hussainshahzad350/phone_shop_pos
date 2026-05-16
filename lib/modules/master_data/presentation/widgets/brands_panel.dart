import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/brand_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/brand_form_dialog.dart';

class BrandsPanel extends ConsumerStatefulWidget {
  const BrandsPanel({super.key});

  @override
  ConsumerState<BrandsPanel> createState() => _BrandsPanelState();
}

class _BrandsPanelState extends ConsumerState<BrandsPanel> {
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
      ref.read(brandSearchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _createBrand() async {
    final data = await showDialog<BrandFormData>(
      context: context,
      builder: (context) => const BrandFormDialog(),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(brandRepositoryProvider.future);
    final uniqueResult = await repository.isNameUnique(data.name);
    if (uniqueResult.isFailure || uniqueResult.asSuccess!.value == false) {
      AppNotifier.error('Brand name already exists.');
      return;
    }

    final now = DateTime.now().toUtc();
    final result = await repository.createBrand(
      BrandEntity(
        id: '',
        name: data.name,
        isActive: data.isActive,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (result.isSuccess) {
      ref.invalidate(brandListProvider);
      AppNotifier.success('Brand created.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _editBrand(BrandEntity brand) async {
    final data = await showDialog<BrandFormData>(
      context: context,
      builder: (context) => BrandFormDialog(initial: brand),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(brandRepositoryProvider.future);
    final uniqueResult = await repository.isNameUnique(
      data.name,
      excludeId: brand.id,
    );
    if (uniqueResult.isFailure || uniqueResult.asSuccess!.value == false) {
      AppNotifier.error('Brand name already exists.');
      return;
    }

    final result = await repository.updateBrand(
      brand.copyWith(name: data.name, isActive: data.isActive),
    );
    if (result.isSuccess) {
      ref.invalidate(brandListProvider);
      AppNotifier.success('Brand updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(BrandEntity brand) async {
    final repository = await ref.read(brandRepositoryProvider.future);
    final result = await repository.setActive(
      brand.id,
      active: !brand.isActive,
    );
    if (result.isSuccess) {
      ref.invalidate(brandListProvider);
      AppNotifier.info(
        brand.isActive ? 'Brand archived.' : 'Brand re-activated.',
      );
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final includeInactive = ref.watch(brandIncludeInactiveProvider);
    final brandsAsync = ref.watch(brandListProvider);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search brands',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: includeInactive,
              label: const Text('Show inactive'),
              onSelected: (selected) {
                ref.read(brandIncludeInactiveProvider.notifier).state =
                    selected;
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _createBrand,
              icon: const Icon(Icons.add),
              label: const Text('Add Brand'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: brandsAsync.when(
                data: (items) => AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(item.name)),
                            DataCell(
                                Text(item.isActive ? 'Active' : 'Archived')),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  IconButton(
                                    onPressed: () => _editBrand(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
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
                      Text('Error loading brands: $error'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(brandListProvider),
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
