import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';

final supplierSearchResultsProvider = FutureProvider<List<SupplierOptionEntity>>((
  ref,
) async {
  final query = ref.watch(purchaseFormStateProvider).supplierSearchQuery.trim();
  final repository = await ref.watch(purchaseRepositoryProvider.future);
  final result = await repository.searchSuppliers(query, limit: 30);
  return result.fold(
    onSuccess: (suppliers) => suppliers,
    onFailure: (error) => const <SupplierOptionEntity>[],
  );
});

/// The next systematic purchase invoice number to preview in the form when the
/// user leaves the invoice field empty. Invalidate after a save to advance it.
final nextPurchaseInvoiceNumberProvider = FutureProvider<String?>((ref) async {
  final repository = await ref.watch(purchaseRepositoryProvider.future);
  final result = await repository.peekNextInvoiceNumber();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => null,
  );
});

final purchaseProductSearchResultsProvider = FutureProvider<List<ProductEntity>>((
  ref,
) async {
  final query = ref.watch(purchaseFormStateProvider).productSearchQuery.trim();
  final repository = await ref.watch(purchaseRepositoryProvider.future);
  final result = await repository.searchProducts(query, limit: 30);
  return result.fold(
    onSuccess: (products) => products,
    onFailure: (error) => const <ProductEntity>[],
  );
});
