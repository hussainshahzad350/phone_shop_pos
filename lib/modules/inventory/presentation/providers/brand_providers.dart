import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';

final brandSearchQueryProvider = StateProvider<String>((ref) => '');
final brandIncludeInactiveProvider = StateProvider<bool>((ref) => false);

final brandListProvider = FutureProvider<List<BrandEntity>>((ref) async {
  final query = ref.watch(brandSearchQueryProvider).trim();
  final includeInactive = ref.watch(brandIncludeInactiveProvider);
  final repository = await ref.watch(brandRepositoryProvider.future);
  final result = await repository.searchBrands(
    query,
    isActive: includeInactive ? null : true,
    limit: 200,
  );
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (_) => const <BrandEntity>[],
  );
});
