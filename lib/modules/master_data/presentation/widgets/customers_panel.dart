import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/debouncer.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/customers/presentation/providers/customer_providers.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/customer_form_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class CustomersPanel extends ConsumerStatefulWidget {
  const CustomersPanel({super.key});

  @override
  ConsumerState<CustomersPanel> createState() => _CustomersPanelState();
}

class _CustomersPanelState extends ConsumerState<CustomersPanel> {
  final _searchController = TextEditingController();
  final _debounce = Debouncer();

  @override
  void dispose() {
    _debounce.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce.run(() {
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
      ref.read(reportWorkflowCoordinatorProvider).refreshAfterCustomerChange();
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
      ref.read(reportWorkflowCoordinatorProvider).refreshAfterCustomerChange();
      AppNotifier.success('Customer updated.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _toggleActive(CustomerEntity customer) async {
    final isArchiving = customer.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: isArchiving ? 'Archive Customer' : 'Unarchive Customer',
        message: isArchiving
            ? 'Archive ${customer.name}?'
            : 'Unarchive ${customer.name}?',
        confirmLabel: isArchiving ? 'Archive' : 'Unarchive',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final repository = await ref.read(customerRepositoryProvider.future);
    final result = await repository.setActive(
      customer.id,
      active: !customer.isActive,
    );

    if (result.isSuccess) {
      ref.read(reportWorkflowCoordinatorProvider).refreshAfterCustomerChange();
      AppNotifier.info(
        customer.isActive ? 'Customer archived.' : 'Customer re-activated.',
      );
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Future<void> _deleteCustomer(CustomerEntity customer) async {
    final confirmed = await confirmHardDeleteDialog(
      context,
      entityLabel: 'Customer',
      entityName: customer.name,
      blockedHint: 'Customers with sales/invoice history cannot be deleted '
          '— archive them instead.',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final repository = await ref.read(customerRepositoryProvider.future);
    final result = await repository.deleteCustomer(customer.id);

    if (result.isSuccess) {
      ref.read(reportWorkflowCoordinatorProvider).refreshAfterCustomerChange();
      AppNotifier.success('Customer deleted.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  Widget _buildCustomersTable(List<CustomerEntity> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _CustomersTableLayout.fromWidth(constraints.maxWidth);
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
              .map((column) => _buildCustomerColumn(column, columnWidths))
              .toList(growable: false),
          rows: items.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final item = entry.value;
            return DataRow(
              cells: visibleColumns
                  .map(
                    (column) => _buildCustomerCell(
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

  Map<_CustomersTableColumn, double> _columnWidths({
    required _CustomersTableLayout layout,
    required List<_CustomersTableColumn> visibleColumns,
    required double availableWidth,
  }) {
    final widths = <_CustomersTableColumn, double>{
      for (final column in visibleColumns) column: layout.baseWidth(column),
    };

    final baseWidth =
        widths.values.fold<double>(0, (sum, value) => sum + value);
    final spacingWidth = (visibleColumns.length - 1) * layout.columnSpacing;
    final extraWidth = availableWidth - baseWidth - spacingWidth - 24;

    if (extraWidth > 0) {
      const weightedColumns = <_CustomersTableColumn, int>{
        _CustomersTableColumn.name: 5,
        _CustomersTableColumn.phone: 3,
        _CustomersTableColumn.email: 5,
        _CustomersTableColumn.status: 2,
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

  List<_CustomersTableColumn> _visibleColumns(_CustomersTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_CustomersTableColumn>[
        _CustomersTableColumn.sr,
        _CustomersTableColumn.name,
        _CustomersTableColumn.phone,
        _CustomersTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_CustomersTableColumn>[
        _CustomersTableColumn.sr,
        _CustomersTableColumn.name,
        _CustomersTableColumn.phone,
        _CustomersTableColumn.status,
        _CustomersTableColumn.actions,
      ];
    }
    return const <_CustomersTableColumn>[
      _CustomersTableColumn.sr,
      _CustomersTableColumn.name,
      _CustomersTableColumn.phone,
      _CustomersTableColumn.email,
      _CustomersTableColumn.status,
      _CustomersTableColumn.actions,
    ];
  }

  DataColumn _buildCustomerColumn(
    _CustomersTableColumn column,
    Map<_CustomersTableColumn, double> widths,
  ) {
    return DataColumn(
      numeric: false,
      label: _labelCell(_columnLabel(column), width: widths[column]!),
    );
  }

  DataCell _buildCustomerCell(
    CustomerEntity item, {
    required int rowNumber,
    required _CustomersTableColumn column,
    required Map<_CustomersTableColumn, double> columnWidths,
  }) {
    switch (column) {
      case _CustomersTableColumn.sr:
        return DataCell(
            _textCell(rowNumber.toString(), width: columnWidths[column]!));
      case _CustomersTableColumn.name:
        return DataCell(_textCell(item.name, width: columnWidths[column]!));
      case _CustomersTableColumn.phone:
        return DataCell(
            _textCell(item.phone ?? '-', width: columnWidths[column]!));
      case _CustomersTableColumn.email:
        return DataCell(
            _textCell(item.email ?? '-', width: columnWidths[column]!));
      case _CustomersTableColumn.status:
        return DataCell(
            _statusCell(item.isActive, width: columnWidths[column]!));
      case _CustomersTableColumn.actions:
        return DataCell(
          SizedBox(
            width: columnWidths[column],
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Edit',
                  onPressed: () => _editCustomer(item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: AppSpacing.xs),
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
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  tooltip: 'Delete permanently',
                  onPressed: () => _deleteCustomer(item),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
    }
  }

  String _columnLabel(_CustomersTableColumn column) {
    switch (column) {
      case _CustomersTableColumn.sr:
        return 'SR#';
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
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppStatusBadge(
          label: isActive ? 'Active' : 'Archived',
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          foreground: isActive
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: customersAsync.when(
                data: _buildCustomersTable,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppErrorState(
                  message: 'Error loading customers: $error',
                  onRetry: () => ref.invalidate(customerListProvider),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CustomersTableColumn {
  sr,
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
    final m = ResponsiveTableLayout.fromWidth(width);
    return _CustomersTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
      showMediumColumns: m.showMediumColumns,
      showCompactColumns: m.showCompactColumns,
      isWideDesktop: m.isWideDesktop,
    );
  }

  double baseWidth(_CustomersTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _CustomersTableColumn.sr:
          return 56;
        case _CustomersTableColumn.name:
          return 300;
        case _CustomersTableColumn.phone:
          return 170;
        case _CustomersTableColumn.email:
          return 260;
        case _CustomersTableColumn.status:
          return 130;
        case _CustomersTableColumn.actions:
          return 176;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _CustomersTableColumn.sr:
          return 52;
        case _CustomersTableColumn.name:
          return 250;
        case _CustomersTableColumn.phone:
          return 160;
        case _CustomersTableColumn.email:
          return 190;
        case _CustomersTableColumn.status:
          return 120;
        case _CustomersTableColumn.actions:
          return 172;
      }
    }
    switch (column) {
      case _CustomersTableColumn.sr:
        return 48;
      case _CustomersTableColumn.name:
        return 220;
      case _CustomersTableColumn.phone:
        return 150;
      case _CustomersTableColumn.email:
        return 160;
      case _CustomersTableColumn.status:
        return 112;
      case _CustomersTableColumn.actions:
        return 168;
    }
  }
}
