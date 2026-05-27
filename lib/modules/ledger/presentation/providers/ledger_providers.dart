import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/ledger/data/repositories/sqlite_customer_ledger_repository.dart';
import 'package:phone_shop_pos/modules/ledger/data/repositories/sqlite_supplier_ledger_repository.dart';
import 'package:phone_shop_pos/modules/ledger/domain/repositories/customer_ledger_repository.dart';
import 'package:phone_shop_pos/modules/ledger/domain/repositories/supplier_ledger_repository.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';

final customerLedgerRepositoryProvider =
    FutureProvider<CustomerLedgerRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteCustomerLedgerRepository(appDatabase: appDatabase);
});

final supplierLedgerRepositoryProvider =
    FutureProvider<SupplierLedgerRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteSupplierLedgerRepository(appDatabase: appDatabase);
});

final ledgerPostingServiceProvider = FutureProvider<LedgerPostingService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final customerRepository =
      await ref.watch(customerLedgerRepositoryProvider.future);
  final supplierRepository =
      await ref.watch(supplierLedgerRepositoryProvider.future);
  return LedgerPostingService(
    appDatabase: appDatabase,
    customerLedgerRepository: customerRepository,
    supplierLedgerRepository: supplierRepository,
  );
});
