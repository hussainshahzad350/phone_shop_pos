import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_state_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/inventory_filter_chips.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/inventory_search_bar.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/widgets/stock_table_widget.dart';

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
    AppNotifier.info('Inventory refreshed.');
  }

  void _debouncedSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
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
    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider, (previous, next) {
      _handleGlobalShortcut(next);
    });

    final filter = ref.watch(inventoryFilterProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final stockAsync = ref.watch(stockRowsProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.f5): const _RefreshIntent(),
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
