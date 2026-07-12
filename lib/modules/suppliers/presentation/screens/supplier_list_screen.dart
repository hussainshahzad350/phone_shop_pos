import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/debouncer.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_summary_entity.dart';
import 'package:phone_shop_pos/modules/suppliers/presentation/providers/supplier_info_providers.dart';

enum _SortColumn { name, phone, totalPurchases, currentStock, totalValue, lastPurchase }

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() =>
      _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchController = TextEditingController();
  final _debounce = Debouncer();
  _SortColumn _sortColumn = _SortColumn.name;
  bool _sortAscending = true;

  @override
  void dispose() {
    _debounce.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce.run(() {
      if (!mounted) return;
      ref.read(supplierInfoSearchQueryProvider.notifier).state = value;
    });
  }

  List<SupplierSummaryEntity> _sorted(List<SupplierSummaryEntity> items) {
    final sorted = List<SupplierSummaryEntity>.of(items);
    int compare(SupplierSummaryEntity a, SupplierSummaryEntity b) {
      switch (_sortColumn) {
        case _SortColumn.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortColumn.phone:
          return (a.phone ?? '').compareTo(b.phone ?? '');
        case _SortColumn.totalPurchases:
          return a.totalPurchases.compareTo(b.totalPurchases);
        case _SortColumn.currentStock:
          return a.currentStock.compareTo(b.currentStock);
        case _SortColumn.totalValue:
          return a.totalPurchaseValue.compareTo(b.totalPurchaseValue);
        case _SortColumn.lastPurchase:
          final aDate = a.lastPurchaseDate;
          final bDate = b.lastPurchaseDate;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return -1;
          if (bDate == null) return 1;
          return aDate.compareTo(bDate);
      }
    }

    sorted.sort(compare);
    if (!_sortAscending) {
      return sorted.reversed.toList(growable: false);
    }
    return sorted;
  }

  void _onSort(_SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(supplierSummariesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Supplier Information',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: 'Search suppliers by name or phone...',
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: summariesAsync.when(
                  data: (items) => _buildTable(context, _sorted(items)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorState(
                    message: 'Error loading suppliers: $error',
                    onRetry: () => ref.invalidate(supplierSummariesProvider),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<SupplierSummaryEntity> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        message: 'No suppliers found.',
        icon: Icons.local_shipping_outlined,
      );
    }

    DataColumn sortableColumn(String label, _SortColumn column) {
      return DataColumn(
        label: Text(label),
        onSort: (_, __) => _onSort(column),
      );
    }

    return AppDataTable(
      showCheckboxColumn: false,
      columns: <DataColumn>[
        sortableColumn('Supplier Name', _SortColumn.name),
        sortableColumn('Phone', _SortColumn.phone),
        sortableColumn('Total Purchases', _SortColumn.totalPurchases),
        sortableColumn('Current Stock', _SortColumn.currentStock),
        sortableColumn('Total Purchase Value', _SortColumn.totalValue),
        sortableColumn('Last Purchase Date', _SortColumn.lastPurchase),
      ],
      rows: items.map((item) {
        return DataRow(
          onSelectChanged: (_) =>
              context.go('/suppliers/${item.supplierId}'),
          cells: <DataCell>[
            DataCell(Text(item.name)),
            DataCell(Text(item.phone ?? '-')),
            DataCell(Text('${item.totalPurchases}')),
            DataCell(Text('${item.currentStock}')),
            DataCell(Text(FormattingHelpers.currencyPkr(item.totalPurchaseValue))),
            DataCell(Text(
              item.lastPurchaseDate != null
                  ? FormattingHelpers.dateYmd(item.lastPurchaseDate!)
                  : '-',
            )),
          ],
        );
      }).toList(growable: false),
    );
  }
}
