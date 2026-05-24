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

  Widget _buildSuppliersTable(List<SupplierEntity> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _SuppliersTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = _visibleColumns(layout);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns: visibleColumns
              .map((column) => _buildSupplierColumn(column, layout))
              .toList(growable: false),
          rows: items
              .map(
                (item) => DataRow(
                  cells: visibleColumns
                      .map(
                        (column) => _buildSupplierCell(item, column, layout),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  List<_SuppliersTableColumn> _visibleColumns(_SuppliersTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_SuppliersTableColumn>[
        _SuppliersTableColumn.name,
        _SuppliersTableColumn.phone,
        _SuppliersTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_SuppliersTableColumn>[
        _SuppliersTableColumn.name,
        _SuppliersTableColumn.phone,
        _SuppliersTableColumn.status,
        _SuppliersTableColumn.actions,
      ];
    }
    return const <_SuppliersTableColumn>[
      _SuppliersTableColumn.name,
      _SuppliersTableColumn.phone,
      _SuppliersTableColumn.contact,
      _SuppliersTableColumn.status,
      _SuppliersTableColumn.actions,
    ];
  }

  DataColumn _buildSupplierColumn(
    _SuppliersTableColumn column,
    _SuppliersTableLayout layout,
  ) {
    return DataColumn(
      label: _labelCell(_columnLabel(column), width: layout.valueWidth(column)),
    );
  }

  DataCell _buildSupplierCell(
    SupplierEntity item,
    _SuppliersTableColumn column,
    _SuppliersTableLayout layout,
  ) {
    switch (column) {
      case _SuppliersTableColumn.name:
        return DataCell(_textCell(item.name, width: layout.valueWidth(column)));
      case _SuppliersTableColumn.phone:
        return DataCell(
          _textCell(item.phone ?? '-', width: layout.valueWidth(column)),
        );
      case _SuppliersTableColumn.contact:
        return DataCell(
          _textCell(item.contactPerson ?? '-',
              width: layout.valueWidth(column)),
        );
      case _SuppliersTableColumn.status:
        return DataCell(
          _textCell(
            item.isActive ? 'Active' : 'Archived',
            width: layout.valueWidth(column),
          ),
        );
      case _SuppliersTableColumn.actions:
        return DataCell(
          SizedBox(
            width: layout.valueWidth(column),
            child: Wrap(
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
        );
    }
  }

  String _columnLabel(_SuppliersTableColumn column) {
    switch (column) {
      case _SuppliersTableColumn.name:
        return 'Name';
      case _SuppliersTableColumn.phone:
        return 'Phone';
      case _SuppliersTableColumn.contact:
        return 'Contact';
      case _SuppliersTableColumn.status:
        return 'Status';
      case _SuppliersTableColumn.actions:
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
                data: _buildSuppliersTable,
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

enum _SuppliersTableColumn {
  name,
  phone,
  contact,
  status,
  actions,
}

class _SuppliersTableLayout {
  const _SuppliersTableLayout({
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

  factory _SuppliersTableLayout.fromWidth(double width) {
    if (width >= 1600) {
      return const _SuppliersTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1220) {
      return const _SuppliersTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return const _SuppliersTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }

  double valueWidth(_SuppliersTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _SuppliersTableColumn.name:
          return 320;
        case _SuppliersTableColumn.phone:
          return 170;
        case _SuppliersTableColumn.contact:
          return 220;
        case _SuppliersTableColumn.status:
          return 120;
        case _SuppliersTableColumn.actions:
          return 120;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _SuppliersTableColumn.name:
          return 260;
        case _SuppliersTableColumn.phone:
          return 160;
        case _SuppliersTableColumn.contact:
          return 170;
        case _SuppliersTableColumn.status:
          return 110;
        case _SuppliersTableColumn.actions:
          return 110;
      }
    }
    switch (column) {
      case _SuppliersTableColumn.name:
        return 220;
      case _SuppliersTableColumn.phone:
        return 140;
      case _SuppliersTableColumn.contact:
        return 140;
      case _SuppliersTableColumn.status:
        return 95;
      case _SuppliersTableColumn.actions:
        return 100;
    }
  }
}
