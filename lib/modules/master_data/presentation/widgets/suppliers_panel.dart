import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/supplier_form_dialog.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';

class SuppliersPanel extends ConsumerStatefulWidget {
  const SuppliersPanel({super.key});

  @override
  ConsumerState<SuppliersPanel> createState() => _SuppliersPanelState();
}

class _SuppliersPanelState extends ConsumerState<SuppliersPanel> {
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
      ref.read(supplierSearchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _createSupplier() async {
    final data = await showDialog<SupplierFormData>(
      context: context,
      builder: (context) => const SupplierFormDialog(),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(supplierRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final result = await repository.createSupplier(
      SupplierEntity(
        id: '',
        name: data.name,
        contactPerson: data.contactPerson,
        phone: data.phone,
        email: data.email,
        address: data.address,
        notes: data.notes,
        isActive: data.isActive,
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (result.isSuccess) {
      ref.invalidate(supplierListProvider);
      AppNotifier.success('Supplier created.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _editSupplier(SupplierEntity supplier) async {
    final data = await showDialog<SupplierFormData>(
      context: context,
      builder: (context) => SupplierFormDialog(initial: supplier),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(supplierRepositoryProvider.future);
    final result = await repository.updateSupplier(
      supplier.copyWith(
        name: data.name,
        contactPerson: data.contactPerson,
        phone: data.phone,
        email: data.email,
        address: data.address,
        notes: data.notes,
        isActive: data.isActive,
      ),
    );

    if (result.isSuccess) {
      ref.invalidate(supplierListProvider);
      AppNotifier.success('Supplier updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(SupplierEntity supplier) async {
    final repository = await ref.read(supplierRepositoryProvider.future);
    final result = await repository.setActive(
      supplier.id,
      active: !supplier.isActive,
    );

    if (result.isSuccess) {
      ref.invalidate(supplierListProvider);
      AppNotifier.info(
        supplier.isActive ? 'Supplier archived.' : 'Supplier re-activated.',
      );
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final includeInactive = ref.watch(supplierIncludeInactiveProvider);
    final suppliersAsync = ref.watch(supplierListProvider);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search suppliers',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: includeInactive,
              label: const Text('Show inactive'),
              onSelected: (selected) {
                ref.read(supplierIncludeInactiveProvider.notifier).state =
                    selected;
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _createSupplier,
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: suppliersAsync.when(
                data: (items) => AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Contact')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(item.name)),
                            DataCell(Text(item.phone ?? '-')),
                            DataCell(Text(item.contactPerson ?? '-')),
                            DataCell(
                                Text(item.isActive ? 'Active' : 'Archived')),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  IconButton(
                                    onPressed: () => _editSupplier(item),
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
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
