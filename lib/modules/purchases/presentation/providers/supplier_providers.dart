import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_supplier_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/supplier_repository.dart';

final supplierRepositoryProvider =
    FutureProvider<SupplierRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteSupplierRepository(appDatabase: appDatabase);
});

final supplierSearchQueryProvider = StateProvider<String>((ref) => '');
final supplierIncludeInactiveProvider = StateProvider<bool>((ref) => false);

final supplierListProvider = FutureProvider<List<SupplierEntity>>((ref) async {
  final query = ref.watch(supplierSearchQueryProvider).trim();
  final includeInactive = ref.watch(supplierIncludeInactiveProvider);
  final repository = await ref.watch(supplierRepositoryProvider.future);
  final result = await repository.searchSuppliers(
    query,
    isActive: includeInactive ? null : true,
    limit: 200,
  );
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (_) => const <SupplierEntity>[],
  );
});
