import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/repairing/data/repositories/sqlite_repairing_repository.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';

/// Behavioural coverage for the previously untested repairing repository.
/// Focuses on the money-and-state rules: payment accumulation and its bounds,
/// the "cannot deliver with pending payment" gate, and soft-delete/restore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  late SqliteRepairingRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('phone_shop_pos_repairing_');
    db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
    repo = SqliteRepairingRepository(appDatabase: db);
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  RepairJobEntity job({
    required String id,
    String status = RepairJobEntity.statusReceived,
    double advance = 0,
    double? finalCost,
    String phoneModel = 'iPhone 11',
    String customerName = 'Ali',
    String? customerPhone,
    String problem = 'Screen broken',
  }) =>
      RepairJobEntity(
        id: id,
        repairDate: DateTime.utc(2024, 6, 1),
        phoneModel: phoneModel,
        problemDescription: problem,
        status: status,
        createdAt: DateTime.utc(2024, 6, 1),
        customerName: customerName,
        customerPhone: customerPhone,
        advanceReceived: advance,
        finalCost: finalCost,
      );

  group('addRepairJob / getRepairJobById', () {
    test('persists a repair job and reads it back', () async {
      _ok(await repo.addRepairJob(
        job(id: 'rep-1', finalCost: 5000, advance: 1000),
      ));

      final fetched = _ok(await repo.getRepairJobById('rep-1'));
      expect(fetched, isNotNull);
      expect(fetched!.phoneModel, 'iPhone 11');
      expect(fetched.customerName, 'Ali');
      expect(fetched.finalCost, closeTo(5000, 0.0001));
      expect(fetched.advanceReceived, closeTo(1000, 0.0001));
      expect(fetched.status, RepairJobEntity.statusReceived);
    });

    test('returns null for an unknown id', () async {
      final fetched = _ok(await repo.getRepairJobById('does-not-exist'));
      expect(fetched, isNull);
    });
  });

  group('getRepairJobs filtering', () {
    test('filters by status and search query, excludes deleted', () async {
      _ok(await repo.addRepairJob(
        job(id: 'rep-a', status: RepairJobEntity.statusReady, phoneModel: 'iPhone 12'),
      ));
      _ok(await repo.addRepairJob(
        job(id: 'rep-b', status: RepairJobEntity.statusReceived, phoneModel: 'Galaxy S21'),
      ));

      final ready = _ok(await repo.getRepairJobs(
        status: RepairJobEntity.statusReady,
      ));
      expect(ready.map((j) => j.id), <String>['rep-a']);

      final iphone = _ok(await repo.getRepairJobs(searchQuery: 'iPhone'));
      expect(iphone.map((j) => j.id), <String>['rep-a']);

      final all = _ok(await repo.getRepairJobs());
      expect(all.map((j) => j.id).toSet(), <String>{'rep-a', 'rep-b'});
    });
  });

  group('collectPayment', () {
    test('accumulates advance_received on the job', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-p', finalCost: 5000)));

      _ok(await repo.collectPayment('rep-p', 2000));
      var fetched = _ok(await repo.getRepairJobById('rep-p'));
      expect(fetched!.advanceReceived, closeTo(2000, 0.0001));

      _ok(await repo.collectPayment('rep-p', 1500));
      fetched = _ok(await repo.getRepairJobById('rep-p'));
      expect(fetched!.advanceReceived, closeTo(3500, 0.0001));
    });

    test('rejects a non-positive amount', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-z', finalCost: 5000)));
      final result = await repo.collectPayment('rep-z', 0);
      expect(result.isFailure, isTrue);
    });

    test('rejects collecting more than the final cost', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-over', finalCost: 5000)));
      _ok(await repo.collectPayment('rep-over', 3000));

      final result = await repo.collectPayment('rep-over', 3000);
      expect(result.isFailure, isTrue);

      // The rejected payment must not have mutated the balance.
      final fetched = _ok(await repo.getRepairJobById('rep-over'));
      expect(fetched!.advanceReceived, closeTo(3000, 0.0001));
    });

    test('rejects payment on a delivered job', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-del', finalCost: 5000)));
      _ok(await repo.collectPayment('rep-del', 5000));
      _ok(await repo.updateStatus('rep-del', RepairJobEntity.statusDelivered));

      final result = await repo.collectPayment('rep-del', 100);
      expect(result.isFailure, isTrue);
    });
  });

  group('updateStatus delivery gate', () {
    test('cannot mark delivered while payment is pending', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-pend', finalCost: 5000)));

      final blocked =
          await repo.updateStatus('rep-pend', RepairJobEntity.statusDelivered);
      expect(blocked.isFailure, isTrue);

      final still = _ok(await repo.getRepairJobById('rep-pend'));
      expect(still!.status, RepairJobEntity.statusReceived);
    });

    test('can mark delivered once fully paid', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-ok', finalCost: 5000)));
      _ok(await repo.collectPayment('rep-ok', 5000));

      _ok(await repo.updateStatus('rep-ok', RepairJobEntity.statusDelivered));
      final fetched = _ok(await repo.getRepairJobById('rep-ok'));
      expect(fetched!.status, RepairJobEntity.statusDelivered);
    });

    test('non-delivery status changes are always allowed', () async {
      _ok(await repo.addRepairJob(job(id: 'rep-s')));
      _ok(await repo.updateStatus('rep-s', RepairJobEntity.statusRepairing));
      final fetched = _ok(await repo.getRepairJobById('rep-s'));
      expect(fetched!.status, RepairJobEntity.statusRepairing);
    });
  });

  group('soft delete and restore', () {
    test('deleted jobs disappear from default queries and can be restored',
        () async {
      _ok(await repo.addRepairJob(job(id: 'rep-d')));

      _ok(await repo.deleteRepairJob('rep-d'));
      expect(_ok(await repo.getRepairJobById('rep-d')), isNull);
      expect(_ok(await repo.getRepairJobs()).map((j) => j.id), isEmpty);

      // includeArchived surfaces the soft-deleted row.
      final archived = _ok(await repo.getRepairJobs(includeArchived: true));
      expect(archived.map((j) => j.id), contains('rep-d'));

      _ok(await repo.restoreRepairJob('rep-d'));
      expect(_ok(await repo.getRepairJobById('rep-d')), isNotNull);
    });
  });

  group('analytics smoke', () {
    test('getRepairKpis and getRepairAnalytics execute over seeded data',
        () async {
      _ok(await repo.addRepairJob(
        job(id: 'rep-k1', status: RepairJobEntity.statusReady, finalCost: 3000),
      ));
      _ok(await repo.addRepairJob(
        job(id: 'rep-k2', status: RepairJobEntity.statusReceived),
      ));

      final kpis = _ok(await repo.getRepairKpis());
      expect(kpis.pendingRepairs, greaterThanOrEqualTo(0));
      expect(kpis.receivedToday, greaterThanOrEqualTo(0));

      final analytics = _ok(await repo.getRepairAnalytics());
      expect(analytics.totalRepairs, greaterThanOrEqualTo(2));
    });
  });
}

T _ok<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.isFailure ? result.asFailure!.error.message : '',
  );
  return result.asSuccess!.value;
}
