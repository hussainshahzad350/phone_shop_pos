import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/providers/ledger_providers.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_calculator.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_handler.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

final purchaseRepositoryProvider = FutureProvider<PurchaseRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final ledgerPostingService = await ref.watch(ledgerPostingServiceProvider.future);
  return SqlitePurchaseRepository.withLedger(
    appDatabase: appDatabase,
    ledgerPostingService: ledgerPostingService,
  );
});

final purchaseCalculatorProvider = Provider<PurchaseCalculator>(
  (ref) => const PurchaseCalculator(),
);

final purchaseServiceProvider = FutureProvider<PurchaseService>((ref) async {
  final repository = await ref.watch(purchaseRepositoryProvider.future);
  return PurchaseService(repository: repository);
});

final purchaseScannerHandlerProvider = Provider<PurchaseScannerHandler>(
  (ref) => PurchaseScannerHandler(ref: ref),
);
