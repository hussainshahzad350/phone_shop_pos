import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/print_job_repository.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('Print queue persistence hardening', () {
    test('persists queued jobs across repository reloads', () async {
      final context = await _PrintQueueContext.createTemporary();
      addTearDown(context.dispose);

      final enqueueResult = await context.repository.enqueue(context.document);
      expect(enqueueResult.isSuccess, isTrue);

      final reloadedContext =
          await _PrintQueueContext.create(context.rootDirectory);
      addTearDown(() => reloadedContext.dispose(deleteRoot: false));
      final jobsResult = await reloadedContext.repository.loadJobs();

      expect(jobsResult.isSuccess, isTrue);
      expect(jobsResult.asSuccess!.value, hasLength(1));
      expect(jobsResult.asSuccess!.value.first.invoiceNumber, 'INV-STRESS-1');
      expect(
        jobsResult.asSuccess!.value.first.status,
        InvoicePrintJobStatus.pending,
      );
    });

    test('recovers stale processing jobs as failed for manual review',
        () async {
      final context = await _PrintQueueContext.createTemporary();
      addTearDown(context.dispose);

      final enqueueResult = await context.repository.enqueue(context.document);
      final jobId = enqueueResult.asSuccess!.value.id;
      final processingResult = await context.repository.markProcessing(jobId);
      expect(processingResult.isSuccess, isTrue);

      await context.appDatabase.update(
        TableNames.printJobs,
        <String, Object?>{
          'updated_at': DateTimeHelpers.toSql(
            DateTimeHelpers.nowUtc().subtract(
              const Duration(minutes: 20),
            ),
          ),
        },
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
      );

      final recoveryResult = await context.repository.recoverAndCleanup();
      expect(recoveryResult.isSuccess, isTrue);

      final jobResult = await context.repository.getJobById(jobId);
      expect(jobResult.isSuccess, isTrue);
      expect(jobResult.asSuccess!.value!.status, InvoicePrintJobStatus.failed);
      expect(jobResult.asSuccess!.value!.lastError, isNotNull);
    });
  });
}

class _PrintQueueContext {
  _PrintQueueContext._({
    required this.rootDirectory,
    required this.appDatabase,
  }) : repository = PrintJobRepository(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final PrintJobRepository repository;

  InvoicePrintDocument get document => InvoicePrintDocument(
        saleId: 'sal_stress_1',
        invoiceNumber: 'INV-STRESS-1',
        saleDate: DateTime.utc(2026, 5, 15),
        items: <CartItemEntity>[
          const CartItemEntity(
            productModelId: 'prd_stress_1',
            productName: 'Stress Phone',
            hasImei: true,
            quantity: 1,
            unitPrice: 75000,
            serializedStockId: 'ser_stress_1',
            imei: '356789101234561',
          ),
        ],
        totals: const SaleTotalsEntity(
          subtotal: 75000,
          discount: 0,
          tax: 0,
          total: 75000,
          paidAmount: 75000,
        ),
        paymentMethod: 'cash',
      );

  static Future<_PrintQueueContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_print_queue_',
    );
    return create(rootDirectory);
  }

  static Future<_PrintQueueContext> create(Directory rootDirectory) async {
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _PrintQueueContext._(
      rootDirectory: rootDirectory,
      appDatabase: appDatabase,
    );
  }

  Future<void> dispose({bool deleteRoot = true}) async {
    await appDatabase.close();
    if (deleteRoot && await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }
}
