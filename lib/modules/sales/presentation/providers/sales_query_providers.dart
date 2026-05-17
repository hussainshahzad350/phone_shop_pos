import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';

final productSearchResultsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final query = ref
      .watch(billingStateProvider.select((state) => state.productSearchQuery))
      .trim();
  final repository = await ref.watch(salesRepositoryProvider.future);
  final result = await repository.searchSellableProducts(query, limit: 30);
  return result.fold(
    onSuccess: (products) => products,
    onFailure: (error) => throw error,
  );
});

final customerSearchResultsProvider = FutureProvider<List<CustomerOptionEntity>>((
  ref,
) async {
  final query = ref
      .watch(billingStateProvider.select((state) => state.customerSearchQuery))
      .trim();
  final repository = await ref.watch(salesRepositoryProvider.future);
  final result = await repository.searchCustomers(query, limit: 30);
  return result.fold(
    onSuccess: (customers) => customers,
    onFailure: (error) => throw error,
  );
});

final availableImeisProvider =
    FutureProvider.autoDispose.family<List<SerializedStockEntity>, String>((
  ref,
  productModelId,
) async {
  final link = ref.keepAlive();
  Timer? disposeTimer;
  ref.onCancel(() {
    disposeTimer = Timer(const Duration(seconds: 20), link.close);
  });
  ref.onResume(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });
  ref.onDispose(() => disposeTimer?.cancel());

  final repository = await ref.watch(salesRepositoryProvider.future);
  final result = await repository.getAvailableImeis(productModelId, limit: 50);
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (error) => throw error,
  );
});
