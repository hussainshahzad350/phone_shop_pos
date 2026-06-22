import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/supplier_form_dialog.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_query_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_query_providers.dart';

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
      ref.invalidate(supplierSearchResultsProvider);
      ref.invalidate(supplierLedgerSummaryProvider);
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
      ref.invalidate(supplierSearchResultsProvider);
      ref.invalidate(supplierLedgerSummaryProvider);
      AppNotifier.success('Supplier updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(SupplierEntity supplier) async {
    final isArchiving = supplier.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: isArchiving ? 'Archive Supplier' : 'Unarchive Supplier',
        message: isArchiving
            ? 'Archive ${supplier.name}?'
            : 'Unarchive ${supplier.name}?',
        confirmLabel: isArchiving ? 'Archive' : 'Unarchive',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final repository = await ref.read(supplierRepositoryProvider.future);
    final result = await repository.setActive(
      supplier.id,
      active: !supplier.isActive,
    );

    if (result.isSuccess) {
      ref.invalidate(supplierListProvider);
      ref.invalidate(supplierSearchResultsProvider);
      ref.invalidate(supplierLedgerSummaryProvider);
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
              .map((column) => _buildSupplierColumn(column, columnWidths))
              .toList(growable: false),
          rows: items.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final item = entry.value;
            return DataRow(
              cells: visibleColumns
                  .map(
                    (column) => _buildSupplierCell(
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

  Map<_SuppliersTableColumn, double> _columnWidths({
    required _SuppliersTableLayout layout,
    required List<_SuppliersTableColumn> visibleColumns,
    required double availableWidth,
  }) {
    final widths = <_SuppliersTableColumn, double>{
      for (final column in visibleColumns) column: layout.baseWidth(column),
    };

    final baseWidth =
        widths.values.fold<double>(0, (sum, value) => sum + value);
    final spacingWidth = (visibleColumns.length - 1) * layout.columnSpacing;
    final extraWidth = availableWidth - baseWidth - spacingWidth - 24;

    if (extraWidth > 0) {
      const weightedColumns = <_SuppliersTableColumn, int>{
        _SuppliersTableColumn.name: 5,
        _SuppliersTableColumn.phone: 3,
        _SuppliersTableColumn.contact: 4,
        _SuppliersTableColumn.status: 2,
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

  List<_SuppliersTableColumn> _visibleColumns(_SuppliersTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_SuppliersTableColumn>[
        _SuppliersTableColumn.sr,
        _SuppliersTableColumn.name,
        _SuppliersTableColumn.phone,
        _SuppliersTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_SuppliersTableColumn>[
        _SuppliersTableColumn.sr,
        _SuppliersTableColumn.name,
        _SuppliersTableColumn.phone,
        _SuppliersTableColumn.status,
        _SuppliersTableColumn.actions,
      ];
    }
    return const <_SuppliersTableColumn>[
      _SuppliersTableColumn.sr,
      _SuppliersTableColumn.name,
      _SuppliersTableColumn.phone,
      _SuppliersTableColumn.contact,
      _SuppliersTableColumn.status,
      _SuppliersTableColumn.actions,
    ];
  }

  DataColumn _buildSupplierColumn(
    _SuppliersTableColumn column,
    Map<_SuppliersTableColumn, double> widths,
  ) {
    return DataColumn(
      numeric: false,
      label: _labelCell(_columnLabel(column), width: widths[column]!),
    );
  }

  DataCell _buildSupplierCell(
    SupplierEntity item, {
    required int rowNumber,
    required _SuppliersTableColumn column,
    required Map<_SuppliersTableColumn, double> columnWidths,
  }) {
    switch (column) {
      case _SuppliersTableColumn.sr:
        return DataCell(
            _textCell(rowNumber.toString(), width: columnWidths[column]!));
      case _SuppliersTableColumn.name:
        return DataCell(_textCell(item.name, width: columnWidths[column]!));
      case _SuppliersTableColumn.phone:
        return DataCell(
            _textCell(item.phone ?? '-', width: columnWidths[column]!));
      case _SuppliersTableColumn.contact:
        return DataCell(
          _textCell(item.contactPerson ?? '-', width: columnWidths[column]!),
        );
      case _SuppliersTableColumn.status:
        return DataCell(
            _statusCell(item.isActive, width: columnWidths[column]!));
      case _SuppliersTableColumn.actions:
        return DataCell(
          SizedBox(
            width: columnWidths[column],
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Edit',
                  onPressed: () => _editSupplier(item),
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

  String _columnLabel(_SuppliersTableColumn column) {
    switch (column) {
      case _SuppliersTableColumn.sr:
        return 'SR#';
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  sr,
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
    final m = ResponsiveTableLayout.fromWidth(width);
    return _SuppliersTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
      showMediumColumns: m.showMediumColumns,
      showCompactColumns: m.showCompactColumns,
      isWideDesktop: m.isWideDesktop,
    );
  }

  double baseWidth(_SuppliersTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _SuppliersTableColumn.sr:
          return 56;
        case _SuppliersTableColumn.name:
          return 300;
        case _SuppliersTableColumn.phone:
          return 170;
        case _SuppliersTableColumn.contact:
          return 220;
        case _SuppliersTableColumn.status:
          return 130;
        case _SuppliersTableColumn.actions:
          return 136;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _SuppliersTableColumn.sr:
          return 52;
        case _SuppliersTableColumn.name:
          return 250;
        case _SuppliersTableColumn.phone:
          return 160;
        case _SuppliersTableColumn.contact:
          return 170;
        case _SuppliersTableColumn.status:
          return 120;
        case _SuppliersTableColumn.actions:
          return 132;
      }
    }
    switch (column) {
      case _SuppliersTableColumn.sr:
        return 48;
      case _SuppliersTableColumn.name:
        return 220;
      case _SuppliersTableColumn.phone:
        return 140;
      case _SuppliersTableColumn.contact:
        return 140;
      case _SuppliersTableColumn.status:
        return 112;
      case _SuppliersTableColumn.actions:
        return 128;
    }
  }
}
