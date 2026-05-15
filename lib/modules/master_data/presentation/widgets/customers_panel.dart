import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/customers/presentation/providers/customer_providers.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/customer_form_dialog.dart';

class CustomersPanel extends ConsumerStatefulWidget {
  const CustomersPanel({super.key});

  @override
  ConsumerState<CustomersPanel> createState() => _CustomersPanelState();
}

class _CustomersPanelState extends ConsumerState<CustomersPanel> {
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
      ref.read(customerSearchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _createCustomer() async {
    final data = await showDialog<CustomerFormData>(
      context: context,
      builder: (context) => const CustomerFormDialog(),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(customerRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final result = await repository.createCustomer(
      CustomerEntity(
        id: '',
        name: data.name,
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
      ref.invalidate(customerListProvider);
      AppNotifier.success('Customer created.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _editCustomer(CustomerEntity customer) async {
    final data = await showDialog<CustomerFormData>(
      context: context,
      builder: (context) => CustomerFormDialog(initial: customer),
    );
    if (data == null) {
      return;
    }

    final repository = await ref.read(customerRepositoryProvider.future);
    final result = await repository.updateCustomer(
      customer.copyWith(
        name: data.name,
        phone: data.phone,
        email: data.email,
        address: data.address,
        notes: data.notes,
        isActive: data.isActive,
      ),
    );

    if (result.isSuccess) {
      ref.invalidate(customerListProvider);
      AppNotifier.success('Customer updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(CustomerEntity customer) async {
    final repository = await ref.read(customerRepositoryProvider.future);
    final result = await repository.setActive(
      customer.id,
      active: !customer.isActive,
    );

    if (result.isSuccess) {
      ref.invalidate(customerListProvider);
      AppNotifier.info(
        customer.isActive ? 'Customer archived.' : 'Customer re-activated.',
      );
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final includeInactive = ref.watch(customerIncludeInactiveProvider);
    final customersAsync = ref.watch(customerListProvider);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search customers',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: includeInactive,
              label: const Text('Show inactive'),
              onSelected: (selected) {
                ref.read(customerIncludeInactiveProvider.notifier).state =
                    selected;
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _createCustomer,
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: customersAsync.when(
                data: (items) => AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(item.name)),
                            DataCell(Text(item.phone ?? '-')),
                            DataCell(Text(item.email ?? '-')),
                            DataCell(
                                Text(item.isActive ? 'Active' : 'Archived')),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  IconButton(
                                    onPressed: () => _editCustomer(item),
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
