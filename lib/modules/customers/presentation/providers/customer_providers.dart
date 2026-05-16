import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/customers/data/repositories/sqlite_customer_repository.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/customers/domain/repositories/customer_repository.dart';

final customerRepositoryProvider =
    FutureProvider<CustomerRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteCustomerRepository(appDatabase: appDatabase);
});

final customerSearchQueryProvider = StateProvider<String>((ref) => '');
final customerIncludeInactiveProvider = StateProvider<bool>((ref) => false);

final customerListProvider = FutureProvider<List<CustomerEntity>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider).trim();
  final includeInactive = ref.watch(customerIncludeInactiveProvider);
  final repository = await ref.watch(customerRepositoryProvider.future);
  final result = await repository.searchCustomers(
    query,
    isActive: includeInactive ? null : true,
    limit: 200,
  );
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (_) => const <CustomerEntity>[],
  );
});
