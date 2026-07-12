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

/// Purchase details of the oldest (FIFO) in-stock unit for a product model —
/// shown directly under the product card so the salesman can see exactly
/// which unit will be sold without a second click, per the single
/// source-of-truth inventory data.
class ProductStockInfo {
  const ProductStockInfo({this.purchaseDate, this.costPrice, this.supplierName});

  final DateTime? purchaseDate;
  final double? costPrice;
  final String? supplierName;
}

/// Batch-resolves [ProductStockInfo] for every serialized product currently
/// shown in the product grid, in one supplier-name lookup instead of one per
/// card.
final productStockInfoProvider =
    FutureProvider<Map<String, ProductStockInfo>>((ref) async {
  final products = await ref.watch(productSearchResultsProvider.future);
  final repository = await ref.watch(salesRepositoryProvider.future);

  final serializedProductIds = products
      .where((product) => product.hasImei)
      .map((product) => product.id)
      .toList(growable: false);
  if (serializedProductIds.isEmpty) {
    return const <String, ProductStockInfo>{};
  }

  final oldestUnits = await Future.wait(
    serializedProductIds.map((productId) async {
      final result = await repository.getAvailableImeis(productId, limit: 1);
      final units = result.fold(
        onSuccess: (items) => items,
        onFailure: (_) => const <SerializedStockEntity>[],
      );
      return MapEntry(productId, units.isEmpty ? null : units.first);
    }),
  );

  final supplierIds = oldestUnits
      .map((entry) => entry.value?.supplierId)
      .whereType<String>()
      .toList(growable: false);
  final supplierNamesResult = await repository.getSupplierNames(supplierIds);
  final supplierNames = supplierNamesResult.fold(
    onSuccess: (names) => names,
    onFailure: (_) => const <String, String>{},
  );

  return <String, ProductStockInfo>{
    for (final entry in oldestUnits)
      if (entry.value != null)
        entry.key: ProductStockInfo(
          purchaseDate: entry.value!.purchaseDate ?? entry.value!.createdAt,
          costPrice: entry.value!.costPrice,
          supplierName: entry.value!.supplierId == null
              ? null
              : supplierNames[entry.value!.supplierId],
        ),
  };
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
