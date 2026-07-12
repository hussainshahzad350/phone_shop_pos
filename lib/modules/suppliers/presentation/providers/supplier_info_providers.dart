import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_summary_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';

final supplierInfoSearchQueryProvider = StateProvider<String>((ref) => '');

final supplierSummariesProvider =
    FutureProvider<List<SupplierSummaryEntity>>((ref) async {
  final query = ref.watch(supplierInfoSearchQueryProvider).trim();
  final repository = await ref.watch(supplierRepositoryProvider.future);
  final result = await repository.getSupplierSummaries(query: query);
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (_) => const <SupplierSummaryEntity>[],
  );
});

final supplierPurchaseHistoryProvider = FutureProvider.family<
    List<SupplierPurchaseHistoryRowEntity>, String>((ref, supplierId) async {
  final repository = await ref.watch(supplierRepositoryProvider.future);
  final result = await repository.getSupplierPurchaseHistory(supplierId);
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (_) => const <SupplierPurchaseHistoryRowEntity>[],
  );
});
