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

  Widget _buildCustomersTable(List<CustomerEntity> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _CustomersTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = _visibleColumns(layout);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns: visibleColumns
              .map((column) => _buildCustomerColumn(column, layout))
              .toList(growable: false),
          rows: items
              .map(
                (item) => DataRow(
                  cells: visibleColumns
                      .map(
                        (column) => _buildCustomerCell(item, column, layout),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  List<_CustomersTableColumn> _visibleColumns(_CustomersTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_CustomersTableColumn>[
        _CustomersTableColumn.name,
        _CustomersTableColumn.phone,
        _CustomersTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_CustomersTableColumn>[
        _CustomersTableColumn.name,
        _CustomersTableColumn.phone,
        _CustomersTableColumn.status,
        _CustomersTableColumn.actions,
      ];
    }
    return const <_CustomersTableColumn>[
      _CustomersTableColumn.name,
      _CustomersTableColumn.phone,
      _CustomersTableColumn.email,
      _CustomersTableColumn.status,
      _CustomersTableColumn.actions,
    ];
  }

  DataColumn _buildCustomerColumn(
    _CustomersTableColumn column,
    _CustomersTableLayout layout,
  ) {
    return DataColumn(
      label: _labelCell(_columnLabel(column), width: layout.valueWidth(column)),
    );
  }

  DataCell _buildCustomerCell(
    CustomerEntity item,
    _CustomersTableColumn column,
    _CustomersTableLayout layout,
  ) {
    switch (column) {
      case _CustomersTableColumn.name:
        return DataCell(_textCell(item.name, width: layout.valueWidth(column)));
      case _CustomersTableColumn.phone:
        return DataCell(
          _textCell(item.phone ?? '-', width: layout.valueWidth(column)),
        );
      case _CustomersTableColumn.email:
        return DataCell(
          _textCell(item.email ?? '-', width: layout.valueWidth(column)),
        );
      case _CustomersTableColumn.status:
        return DataCell(
          _textCell(
            item.isActive ? 'Active' : 'Archived',
            width: layout.valueWidth(column),
          ),
        );
      case _CustomersTableColumn.actions:
        return DataCell(
          SizedBox(
            width: layout.valueWidth(column),
            child: Wrap(
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
        );
    }
  }

  String _columnLabel(_CustomersTableColumn column) {
    switch (column) {
      case _CustomersTableColumn.name:
        return 'Name';
      case _CustomersTableColumn.phone:
        return 'Phone';
      case _CustomersTableColumn.email:
        return 'Email';
      case _CustomersTableColumn.status:
        return 'Status';
      case _CustomersTableColumn.actions:
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
                data: _buildCustomersTable,
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

enum _CustomersTableColumn {
  name,
  phone,
  email,
  status,
  actions,
}

class _CustomersTableLayout {
  const _CustomersTableLayout({
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

  factory _CustomersTableLayout.fromWidth(double width) {
    if (width >= 1600) {
      return const _CustomersTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1220) {
      return const _CustomersTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return const _CustomersTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }

  double valueWidth(_CustomersTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _CustomersTableColumn.name:
          return 320;
        case _CustomersTableColumn.phone:
          return 170;
        case _CustomersTableColumn.email:
          return 260;
        case _CustomersTableColumn.status:
          return 120;
        case _CustomersTableColumn.actions:
          return 120;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _CustomersTableColumn.name:
          return 260;
        case _CustomersTableColumn.phone:
          return 160;
        case _CustomersTableColumn.email:
          return 190;
        case _CustomersTableColumn.status:
          return 110;
        case _CustomersTableColumn.actions:
          return 110;
      }
    }
    switch (column) {
      case _CustomersTableColumn.name:
        return 220;
      case _CustomersTableColumn.phone:
        return 150;
      case _CustomersTableColumn.email:
        return 160;
      case _CustomersTableColumn.status:
        return 95;
      case _CustomersTableColumn.actions:
        return 100;
    }
  }
}
