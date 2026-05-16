import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';

final productManagementSearchQueryProvider = StateProvider<String>((ref) => '');
final productManagementIncludeInactiveProvider =
    StateProvider<bool>((ref) => false);

final managedProductsProvider =
    FutureProvider<List<ProductEntity>>((ref) async {
  final query = ref.watch(productManagementSearchQueryProvider).trim();
  final includeInactive = ref.watch(productManagementIncludeInactiveProvider);
  final repository = await ref.watch(productRepositoryProvider.future);
  final result = await repository.searchProducts(
    query,
    isActive: includeInactive ? null : true,
    limit: 200,
  );
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (error) => throw error,
  );
});
