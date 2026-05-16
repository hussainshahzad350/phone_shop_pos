import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_state_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/inventory_filter_chips.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/inventory_search_bar.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/stock_table_widget.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  int _handledShortcutToken = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(stockRowsProvider);
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(stockAdjustmentHistoryProvider);
    AppNotifier.info('Inventory refreshed.');
  }

  void _debouncedSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      ref.read(inventoryFilterProvider.notifier).setSearch(value);
    });
  }

  void _handleGlobalShortcut(AppShortcutEventState state) {
    if (!mounted || state.token == 0 || state.token == _handledShortcutToken) {
      return;
    }
    _handledShortcutToken = state.token;

    switch (state.event) {
      case AppShortcutEvent.focusSearch:
        _searchFocus.requestFocus();
        break;
      case AppShortcutEvent.refreshCurrentScreen:
        _refresh();
        break;
      case AppShortcutEvent.focusPayment:
      case AppShortcutEvent.saveOrComplete:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider,
        (previous, next) {
      _handleGlobalShortcut(next);
    });

    final filter = ref.watch(inventoryFilterProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final stockAsync = ref.watch(stockRowsProvider);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f5): _RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              _refresh();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final rows = stockAsync.valueOrNull ?? const <StockRowEntity>[];
                        await showDialog<void>(
                          context: context,
                          builder: (context) => _StockAdjustmentDialog(stockRows: rows),
                        );
                        _refresh();
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('Stock Adjustment'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh (F5)',
                      onPressed: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                summaryAsync.when(
                  data: (summary) => _SummaryCards(summary: summary),
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Failed to load summary.')),
                  ),
                ),
                const SizedBox(height: 12),
                InventorySearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  onChanged: _debouncedSearch,
                ),
                const SizedBox(height: 8),
                InventoryFilterChips(
                  selectedStatus: filter.statusFilter,
                  selectedHasImei: filter.hasImeiFilter,
                  onStatusChanged: (status) {
                    ref
                        .read(inventoryFilterProvider.notifier)
                        .setStatusFilter(status);
                  },
                  onTypeChanged: (value) {
                    ref
                        .read(inventoryFilterProvider.notifier)
                        .setHasImeiFilter(value);
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: stockAsync.when(
                        data: (rows) => StockTableWidget(rows: rows),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, _) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('Error loading stock: $error'),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _refresh,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final InventorySummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryCard(
            label: 'Phones In Stock',
            value: summary.inStockPhones.toString(),
            icon: Icons.phone_android,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Sold Phones',
            value: summary.soldPhones.toString(),
            icon: Icons.sell,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Accessory Units',
            value: summary.totalAccessoryUnits.toString(),
            icon: Icons.cable,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Low Stock Alerts',
            value: summary.lowStockCount.toString(),
            icon: Icons.warning_amber,
            color: summary.lowStockCount > 0 ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _StockAdjustmentDialog extends ConsumerStatefulWidget {
  const _StockAdjustmentDialog({required this.stockRows});

  final List<StockRowEntity> stockRows;

  @override
  ConsumerState<_StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<_StockAdjustmentDialog> {
  final TextEditingController _deltaController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedProductModelId;
  String? _selectedSerializedStockId;
  String _reason = 'damage';
  bool _isWriteOff = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _deltaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adjustmentAsync = ref.watch(stockAdjustmentHistoryProvider);
    final quantityProducts = widget.stockRows
        .where((row) => row.type == StockRowType.quantity)
        .toList(growable: false);
    final serializedRows = widget.stockRows
        .where(
          (row) =>
              row.type == StockRowType.serialized &&
              row.serializedStockId != null &&
              row.serializedStatus?.value == 'in_stock',
        )
        .toList(growable: false);

    _selectedProductModelId ??=
        quantityProducts.isNotEmpty ? quantityProducts.first.productModelId : null;
    _selectedSerializedStockId ??=
        serializedRows.isNotEmpty ? serializedRows.first.serializedStockId : null;

    return AlertDialog(
      title: const Text('Stock Adjustment'),
      content: SizedBox(
        width: 980,
        height: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Qty +/-'),
                  selected: !_isWriteOff,
                  onSelected: (_) => setState(() => _isWriteOff = false),
                ),
                ChoiceChip(
                  label: const Text('Write-off IMEI'),
                  selected: _isWriteOff,
                  onSelected: (_) => setState(() => _isWriteOff = true),
                ),
                DropdownButton<String>(
                  value: _reason,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reason = value);
                    }
                  },
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'damage', child: Text('Damage')),
                    DropdownMenuItem<String>(value: 'theft', child: Text('Theft')),
                    DropdownMenuItem<String>(value: 'correction', child: Text('Correction')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_isWriteOff) ...<Widget>[
              DropdownButtonFormField<String>(
                value: _selectedProductModelId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Accessory Product',
                ),
                items: quantityProducts.map((row) {
                  return DropdownMenuItem<String>(
                    value: row.productModelId,
                    child: Text('${row.productName} (Qty: ${row.quantity ?? 0})'),
                  );
                }).toList(growable: false),
                onChanged: (value) => setState(() => _selectedProductModelId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _deltaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Quantity Delta (+/-)',
                ),
              ),
            ] else ...<Widget>[
              DropdownButtonFormField<String>(
                value: _selectedSerializedStockId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'In-stock IMEI',
                ),
                items: serializedRows.map((row) {
                  return DropdownMenuItem<String>(
                    value: row.serializedStockId,
                    child: Text('${row.productName} • ${row.imei1 ?? '-'}'),
                  );
                }).toList(growable: false),
                onChanged: (value) => setState(() => _selectedSerializedStockId = value),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Adjustment History',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: adjustmentAsync.when(
                data: (rows) => AppDataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Delta')),
                    DataColumn(label: Text('Reason')),
                    DataColumn(label: Text('IMEI')),
                  ],
                  rows: rows.map(_toDataRow).toList(growable: false),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('Failed to load adjustment history.'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Apply'),
        ),
      ],
    );
  }

  DataRow _toDataRow(StockAdjustmentHistoryRowEntity row) {
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(FormattingHelpers.dateYmd(row.createdAt))),
        DataCell(Text(row.productName)),
        DataCell(Text(row.adjustmentType)),
        DataCell(Text(row.quantityDelta.toString())),
        DataCell(Text(row.reason)),
        DataCell(Text(row.imei ?? '-')),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final service = await ref.read(operationsWorkflowServiceProvider.future);
    late Result<void> result;

    if (_isWriteOff) {
      final serializedId = _selectedSerializedStockId;
      if (serializedId == null || serializedId.isEmpty) {
        result = const Failure<void>(
          AppError(
            code: 'missing_imei',
            message: 'Select an IMEI to write off.',
          ),
        );
      } else {
        result = await service.writeOffSerializedStock(
          serializedStockId: serializedId,
          reason: _reason,
          notes: _notesController.text,
        );
      }
    } else {
      final productModelId = _selectedProductModelId;
      final delta = int.tryParse(_deltaController.text.trim()) ?? 0;
      if (productModelId == null || productModelId.isEmpty) {
        result = const Failure<void>(
          AppError(
            code: 'missing_product',
            message: 'Select a product for quantity adjustment.',
          ),
        );
      } else {
        final qtyResult = await service.applyQuantityStockAdjustment(
          productModelId: productModelId,
          delta: delta,
          reason: _reason,
          notes: _notesController.text,
        );
        result = qtyResult.fold(
          onSuccess: (_) => const Success<void>(null),
          onFailure: (error) => Failure<void>(error),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
      return;
    }
    AppNotifier.success('Stock adjustment saved.');
    _deltaController.clear();
    _notesController.clear();
    ref.invalidate(stockAdjustmentHistoryProvider);
    ref.invalidate(stockRowsProvider);
    ref.invalidate(inventorySummaryProvider);
  }
}
