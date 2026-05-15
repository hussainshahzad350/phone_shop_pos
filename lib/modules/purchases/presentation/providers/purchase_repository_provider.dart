import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_calculator.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

final purchaseRepositoryProvider = FutureProvider<PurchaseRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqlitePurchaseRepository(appDatabase: appDatabase);
});

final purchaseCalculatorProvider = Provider<PurchaseCalculator>(
  (ref) => const PurchaseCalculator(),
);

final purchaseServiceProvider = FutureProvider<PurchaseService>((ref) async {
  final repository = await ref.watch(purchaseRepositoryProvider.future);
  return PurchaseService(repository: repository);
});
