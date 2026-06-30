import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';

class InventoryFilterState {
  const InventoryFilterState({
    this.searchQuery = '',
    this.statusFilter = SerializedStockStatus.inStock,
    this.hasImeiFilter,
  });

  final String searchQuery;
  final SerializedStockStatus? statusFilter;
  final bool? hasImeiFilter;

  InventoryFilterState copyWith({
    String? searchQuery,
    SerializedStockStatus? statusFilter,
    bool clearStatusFilter = false,
    bool? hasImeiFilter,
    bool clearHasImeiFilter = false,
  }) {
    return InventoryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : statusFilter ?? this.statusFilter,
      hasImeiFilter:
          clearHasImeiFilter ? null : hasImeiFilter ?? this.hasImeiFilter,
    );
  }
}

class InventoryFilterNotifier extends StateNotifier<InventoryFilterState> {
  InventoryFilterNotifier() : super(const InventoryFilterState());

  void setSearch(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setStatusFilter(SerializedStockStatus? status) {
    if (status == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  void setHasImeiFilter(bool? value) {
    if (value == null) {
      state = state.copyWith(clearHasImeiFilter: true);
    } else {
      state = state.copyWith(hasImeiFilter: value);
    }
  }

  void clearFilters() {
    state = const InventoryFilterState();
  }
}

final inventoryFilterProvider =
    StateNotifierProvider<InventoryFilterNotifier, InventoryFilterState>(
  (ref) => InventoryFilterNotifier(),
);
