import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/supplier_payment_service.dart';

/// SupplierPaymentService delegates to a LedgerPostingService; the settlement
/// logic itself lives there. The one behaviour it owns is failing cleanly when
/// no ledger-posting service is configured, which this pins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('phone_shop_pos_supplier_pay_');
    db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('fails when no ledger-posting service is configured', () async {
    final service = SupplierPaymentService(appDatabase: db);

    final result = await service.paySupplierCredit(
      const SupplierSettlementRequestPayload(
        supplierId: 'sup-1',
        amount: 100,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    expect(result.isFailure, isTrue);
  });
}
