import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/providers/ledger_providers.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_handler.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_service.dart';

final salesRepositoryProvider = FutureProvider<SalesRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final ledgerPostingService = await ref.watch(ledgerPostingServiceProvider.future);
  return SqliteSalesRepository.withLedger(
    appDatabase: appDatabase,
    ledgerPostingService: ledgerPostingService,
  );
});

final salesServiceProvider = FutureProvider<SalesService>((ref) async {
  final repository = await ref.watch(salesRepositoryProvider.future);
  return SalesService(repository: repository);
});

final salesCalculatorProvider = Provider<SalesCalculator>(
  (ref) => const SalesCalculator(),
);

final salesScannerHandlerProvider = Provider<SalesScannerHandler>(
  (ref) => SalesScannerHandler(ref: ref),
);
