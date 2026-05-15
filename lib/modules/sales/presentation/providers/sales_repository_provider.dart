import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_service.dart';

final salesRepositoryProvider = FutureProvider<SalesRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteSalesRepository(appDatabase: appDatabase);
});

final salesServiceProvider = FutureProvider<SalesService>((ref) async {
  final repository = await ref.watch(salesRepositoryProvider.future);
  return SalesService(repository: repository);
});

final salesCalculatorProvider = Provider<SalesCalculator>(
  (ref) => const SalesCalculator(),
);
