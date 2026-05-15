import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_state_provider.dart';

final stockRowsProvider = FutureProvider<List<StockRowEntity>>((ref) async {
  final filter = ref.watch(inventoryFilterProvider);
  final service = await ref.watch(inventoryServiceProvider.future);
  final result = await service.getStockRows(
    searchQuery: filter.searchQuery,
    serializedStatusFilter: filter.statusFilter,
    hasImeiFilter: filter.hasImeiFilter,
  );
  return result.fold(
    onSuccess: (rows) => rows,
    onFailure: (error) => const <StockRowEntity>[],
  );
});

final inventorySummaryProvider =
    FutureProvider<InventorySummaryEntity>((ref) async {
  final service = await ref.watch(inventoryServiceProvider.future);
  final result = await service.getInventorySummary();
  return result.fold(
    onSuccess: (summary) => summary,
    onFailure: (error) => const InventorySummaryEntity(
      totalPhones: 0,
      inStockPhones: 0,
      soldPhones: 0,
      reservedPhones: 0,
      totalAccessoryVariants: 0,
      totalAccessoryUnits: 0,
      lowStockCount: 0,
      totalStockValue: 0,
    ),
  );
});

final lowStockProvider = FutureProvider<List<StockRowEntity>>((ref) async {
  final service = await ref.watch(inventoryServiceProvider.future);
  final result = await service.getLowStockRows();
  return result.fold(
    onSuccess: (rows) => rows,
    onFailure: (error) => const <StockRowEntity>[],
  );
});
