import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/brand_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/brand_form_dialog.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class _BrandUsageCounts {
  const _BrandUsageCounts({required this.active, required this.inactive});

  final int active;
  final int inactive;
}

final _brandUsageCountsProvider =
    FutureProvider<Map<String, _BrandUsageCounts>>((ref) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  final result = await repository.searchProducts(
    '',
    isActive: null,
    limit: 10000,
  );
  return result.fold(
    onSuccess: _buildBrandUsageMap,
    onFailure: (error) => throw error,
  );
});

Map<String, _BrandUsageCounts> _buildBrandUsageMap(List<ProductEntity> items) {
  final activeMap = <String, int>{};
  final inactiveMap = <String, int>{};

  for (final item in items) {
    final brand = item.brand?.trim();
    if (brand == null || brand.isEmpty) {
      continue;
    }
    final key = brand.toLowerCase();
    if (item.isActive) {
      activeMap[key] = (activeMap[key] ?? 0) + 1;
    } else {
      inactiveMap[key] = (inactiveMap[key] ?? 0) + 1;
    }
  }

  final keys = <String>{...activeMap.keys, ...inactiveMap.keys};
  return <String, _BrandUsageCounts>{
    for (final key in keys)
      key: _BrandUsageCounts(
        active: activeMap[key] ?? 0,
        inactive: inactiveMap[key] ?? 0,
      ),
  };
}

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
    final isArchiving = brand.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: isArchiving ? 'Archive Brand' : 'Unarchive Brand',
        message:
            isArchiving ? 'Archive ${brand.name}?' : 'Unarchive ${brand.name}?',
        confirmLabel: isArchiving ? 'Archive' : 'Unarchive',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

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

  Widget _buildBrandsTable(
    List<BrandEntity> items,
    Map<String, _BrandUsageCounts> usageByBrand,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _BrandsTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = const <_BrandsTableColumn>[
          _BrandsTableColumn.sr,
          _BrandsTableColumn.name,
          _BrandsTableColumn.activeItems,
          _BrandsTableColumn.inactiveItems,
          _BrandsTableColumn.status,
          _BrandsTableColumn.actions,
        ];
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
              .map((column) => _buildBrandColumn(column, columnWidths))
              .toList(growable: false),
          rows: items.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final item = entry.value;
            return DataRow(
              cells: visibleColumns
                  .map(
                    (column) => _buildBrandCell(
                      item,
                      usageByBrand: usageByBrand,
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

  Map<_BrandsTableColumn, double> _columnWidths({
    required _BrandsTableLayout layout,
    required List<_BrandsTableColumn> visibleColumns,
    required double availableWidth,
  }) {
    final widths = <_BrandsTableColumn, double>{
      for (final column in visibleColumns) column: layout.baseWidth(column),
    };

    final baseWidth =
        widths.values.fold<double>(0, (sum, value) => sum + value);
    final spacingWidth = (visibleColumns.length - 1) * layout.columnSpacing;
    final extraWidth = availableWidth - baseWidth - spacingWidth - 24;

    if (extraWidth > 0) {
      const weightedColumns = <_BrandsTableColumn, int>{
        _BrandsTableColumn.name: 6,
        _BrandsTableColumn.activeItems: 2,
        _BrandsTableColumn.inactiveItems: 2,
        _BrandsTableColumn.status: 2,
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

  DataColumn _buildBrandColumn(
    _BrandsTableColumn column,
    Map<_BrandsTableColumn, double> widths,
  ) {
    return DataColumn(
      numeric: false,
      label: _labelCell(_columnLabel(column), width: widths[column]!),
    );
  }

  DataCell _buildBrandCell(
    BrandEntity item, {
    required Map<String, _BrandUsageCounts> usageByBrand,
    required int rowNumber,
    required _BrandsTableColumn column,
    required Map<_BrandsTableColumn, double> columnWidths,
  }) {
    final usage = usageByBrand[item.name.trim().toLowerCase()];
    switch (column) {
      case _BrandsTableColumn.sr:
        return DataCell(
            _textCell(rowNumber.toString(), width: columnWidths[column]!));
      case _BrandsTableColumn.name:
        return DataCell(_textCell(item.name, width: columnWidths[column]!));
      case _BrandsTableColumn.activeItems:
        return DataCell(
          _textCell(
            (usage?.active ?? 0).toString(),
            width: columnWidths[column]!,
          ),
        );
      case _BrandsTableColumn.inactiveItems:
        return DataCell(
          _textCell(
            (usage?.inactive ?? 0).toString(),
            width: columnWidths[column]!,
          ),
        );
      case _BrandsTableColumn.status:
        return DataCell(
            _statusCell(item.isActive, width: columnWidths[column]!));
      case _BrandsTableColumn.actions:
        return DataCell(
          SizedBox(
            width: columnWidths[column],
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Edit',
                  onPressed: () => _editBrand(item),
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
              ],
            ),
          ),
        );
    }
  }

  String _columnLabel(_BrandsTableColumn column) {
    switch (column) {
      case _BrandsTableColumn.sr:
        return 'SR#';
      case _BrandsTableColumn.name:
        return 'Name';
      case _BrandsTableColumn.activeItems:
        return 'Active Items';
      case _BrandsTableColumn.inactiveItems:
        return 'Inactive Items';
      case _BrandsTableColumn.status:
        return 'Status';
      case _BrandsTableColumn.actions:
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
    final includeInactive = ref.watch(brandIncludeInactiveProvider);
    final brandsAsync = ref.watch(brandListProvider);
    final usageAsync = ref.watch(_brandUsageCountsProvider);

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
            const SizedBox(width: AppSpacing.sm),
            FilterChip(
              selected: includeInactive,
              label: const Text('Show inactive'),
              onSelected: (selected) {
                ref.read(brandIncludeInactiveProvider.notifier).state =
                    selected;
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _createBrand,
              icon: const Icon(Icons.add),
              label: const Text('Add Brand'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: brandsAsync.when(
                data: (items) => _buildBrandsTable(
                  items,
                  usageAsync.valueOrNull ?? const <String, _BrandUsageCounts>{},
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('Error loading brands: $error'),
                      const SizedBox(height: AppSpacing.sm),
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

enum _BrandsTableColumn {
  sr,
  name,
  activeItems,
  inactiveItems,
  status,
  actions,
}

class _BrandsTableLayout {
  const _BrandsTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  factory _BrandsTableLayout.fromWidth(double width) {
    final m = ResponsiveTableLayout.fromWidth(width);
    return _BrandsTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
    );
  }

  double baseWidth(_BrandsTableColumn column) {
    switch (column) {
      case _BrandsTableColumn.sr:
        return 56;
      case _BrandsTableColumn.name:
        return 300;
      case _BrandsTableColumn.activeItems:
        return 110;
      case _BrandsTableColumn.inactiveItems:
        return 118;
      case _BrandsTableColumn.status:
        return 130;
      case _BrandsTableColumn.actions:
        return 136;
    }
  }
}
