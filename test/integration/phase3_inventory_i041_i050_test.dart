import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';

void main() {
  group('PHASE 3 Inventory I-041..I-050', () {
    test('I-041 150 quantity adjustments keep exact final stock', () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i041_acc', 'I041 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i041',
        productModelId: 'prd_i041_acc',
        quantity: 500,
        minQuantity: 30,
      );

      var expected = 500;
      for (var i = 0; i < 150; i++) {
        final delta = i.isEven ? 2 : -1;
        final result =
            await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i041_acc',
          delta: delta,
          reason: 'correction',
        );
        if (result.isSuccess) {
          expected += delta;
        }
      }

      expect(await context.getInventoryQuantity('prd_i041_acc'), expected);
      expect(await context.countAdjustmentsForProduct('prd_i041_acc'), 150);
    });

    test('I-042 Duplicate IMEI write-off submission is safely rejected',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertSerializedProduct('prd_i042_phone', 'I042 Phone');
      await context.insertSerializedStock(
        id: 'ser_i042',
        productModelId: 'prd_i042_phone',
        imei1: '356789101234642',
      );

      final first = await context.operationsService.writeOffSerializedStock(
        serializedStockId: 'ser_i042',
        reason: 'damage',
      );
      final second = await context.operationsService.writeOffSerializedStock(
        serializedStockId: 'ser_i042',
        reason: 'damage',
      );

      expect(first.isSuccess, isTrue);
      expect(second.isFailure, isTrue);
      expect(await context.countWriteOffAdjustments('ser_i042'), 1);
    });

    test('I-043 Concurrent decrements never push stock below zero', () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i043_acc', 'I043 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i043',
        productModelId: 'prd_i043_acc',
        quantity: 10,
        minQuantity: 2,
      );

      final futures = List<Future<Result<int>>>.generate(
        20,
        (_) => context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i043_acc',
          delta: -1,
          reason: 'damage',
        ),
      );

      final results = await Future.wait(futures);
      final successCount = results.where((r) => r.isSuccess).length;
      final failureCount = results.where((r) => r.isFailure).length;

      expect(successCount, 10);
      expect(failureCount, 10);
      expect(await context.getInventoryQuantity('prd_i043_acc'), 0);
    });

    test('I-044 Long mixed inventory session remains stable', () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i044_acc', 'I044 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i044',
        productModelId: 'prd_i044_acc',
        quantity: 200,
        minQuantity: 20,
      );

      for (var i = 0; i < 200; i++) {
        final searchRows = await context.getStockRows(search: 'I044');
        expect(searchRows.isNotEmpty, isTrue);

        if (i % 5 == 0) {
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i044_acc',
            delta: 1,
            reason: 'correction',
          );
        }

        if (i % 7 == 0) {
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i044_acc',
            delta: -1,
            reason: 'damage',
          );
        }
      }

      expect(await context.getInventoryQuantity('prd_i044_acc'),
          greaterThanOrEqualTo(0));
    });

    test('I-045 Backup creation under stress passes integrity validation',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i045_acc', 'I045 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i045',
        productModelId: 'prd_i045_acc',
        quantity: 120,
        minQuantity: 10,
      );

      for (var i = 0; i < 80; i++) {
        _expectSuccess(
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i045_acc',
            delta: i.isEven ? 2 : -1,
            reason: 'correction',
          ),
        );
      }

      final backupInfo = _expectSuccess(
        await context.backupService.createBackup(
          directoryPath: context.backupDirectory.path,
        ),
      );
      final validation = _expectSuccess(
        await context.backupService.validateBackup(backupInfo.path),
      );

      expect(validation, isTrue);
    });

    test('I-046 Restore backup reverts data to snapshot correctly', () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i046_acc', 'I046 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i046',
        productModelId: 'prd_i046_acc',
        quantity: 30,
        minQuantity: 3,
      );

      final backupInfo = _expectSuccess(
        await context.backupService.createBackup(
          directoryPath: context.backupDirectory.path,
        ),
      );

      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i046_acc',
          delta: 25,
          reason: 'correction',
        ),
      );
      expect(await context.getInventoryQuantity('prd_i046_acc'), 55);

      _expectSuccess(
          await context.backupService.restoreBackup(backupInfo.path));
      expect(await context.getInventoryQuantity('prd_i046_acc'), 30);
    });

    test('I-047 Injection-like notes are stored safely without schema damage',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i047_acc', 'I047 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i047',
        productModelId: 'prd_i047_acc',
        quantity: 25,
        minQuantity: 5,
      );

      const payload = "'; DROP TABLE inventory_stock; --";
      _expectSuccess(
        await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i047_acc',
          delta: 2,
          reason: 'correction',
          notes: payload,
        ),
      );

      expect(await context.tableExists(TableNames.inventoryStock), isTrue);
      final latestNotes = await context.latestAdjustmentNotes('prd_i047_acc');
      expect(latestNotes, payload);
    });

    test('I-048 Restart after stress keeps durable stock and audit data',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i048_acc', 'I048 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i048',
        productModelId: 'prd_i048_acc',
        quantity: 70,
        minQuantity: 7,
      );

      for (var i = 0; i < 40; i++) {
        _expectSuccess(
          await context.operationsService.applyQuantityStockAdjustment(
            productModelId: 'prd_i048_acc',
            delta: i % 3 == 0 ? 3 : -1,
            reason: 'correction',
          ),
        );
      }

      final beforeQty = await context.getInventoryQuantity('prd_i048_acc');
      final beforeAudit =
          await context.countAdjustmentsForProduct('prd_i048_acc');

      await context.restart();

      expect(await context.getInventoryQuantity('prd_i048_acc'), beforeQty);
      expect(await context.countAdjustmentsForProduct('prd_i048_acc'),
          beforeAudit);
    });

    test('I-049 High-volume IMEI dataset keeps uniqueness constraints intact',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertSerializedProduct('prd_i049_phone', 'I049 Phone');
      for (var i = 0; i < 100; i++) {
        await context.insertSerializedStock(
          id: 'ser_i049_$i',
          productModelId: 'prd_i049_phone',
          imei1: '35678910123${i.toString().padLeft(4, '0')}',
        );
      }

      final duplicateOk = await context.tryInsertDuplicateImei(
        id: 'ser_i049_dup',
        productModelId: 'prd_i049_phone',
        imei1: '356789101230000',
      );

      expect(duplicateOk, isFalse);
      expect(await context.countSerializedRows('prd_i049_phone'), 100);
    });

    test('I-050 300-step stress adjustments maintain exact invariant',
        () async {
      final context = await _BatchEContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertQuantityProduct('prd_i050_acc', 'I050 Accessory');
      await context.insertInventoryStock(
        id: 'stk_i050',
        productModelId: 'prd_i050_acc',
        quantity: 400,
        minQuantity: 15,
      );

      var expected = 400;
      var successOps = 0;
      for (var i = 0; i < 300; i++) {
        final delta = switch (i % 4) {
          0 => 3,
          1 => -2,
          2 => 1,
          _ => -1,
        };

        final result =
            await context.operationsService.applyQuantityStockAdjustment(
          productModelId: 'prd_i050_acc',
          delta: delta,
          reason: 'correction',
        );
        if (result.isSuccess) {
          expected += delta;
          successOps++;
        }
      }

      expect(await context.getInventoryQuantity('prd_i050_acc'), expected);
      expect(
          await context.countAdjustmentsForProduct('prd_i050_acc'), successOps);
      expect(expected, greaterThanOrEqualTo(0));
    });
  });
}

class _BatchEContext {
  _BatchEContext._({
    required this.rootDirectory,
    required this.backupDirectory,
    required AppDatabase appDatabase,
  }) : _appDatabase = appDatabase;

  final Directory rootDirectory;
  final Directory backupDirectory;
  AppDatabase _appDatabase;

  OperationsWorkflowService get operationsService =>
      OperationsWorkflowService(appDatabase: _appDatabase);
  DatabaseBackupService get backupService =>
      DatabaseBackupService(appDatabase: _appDatabase);

  static Future<_BatchEContext> createTemporary() async {
    final root =
        await Directory.systemTemp.createTemp('phone_shop_pos_phase3_i041_');
    final backup = Directory('${root.path}${Platform.pathSeparator}backups');
    await backup.create(recursive: true);

    final db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: root.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);

    return _BatchEContext._(
      rootDirectory: root,
      backupDirectory: backup,
      appDatabase: db,
    );
  }

  Future<void> restart() async {
    await _appDatabase.close();
    final reopened = AppDatabase(
      localDatabaseService:
          SqliteFfiDatabaseService(rootDirectory: rootDirectory.path),
      migrationService: const MigrationService(),
    );
    await reopened.initialize(seedDemoData: false);
    _appDatabase = reopened;
  }

  Future<void> dispose() async {
    await _appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }

  Future<void> insertQuantityProduct(String id, String name) {
    return _insertProduct(id: id, name: name, hasImei: false);
  }

  Future<void> insertSerializedProduct(String id, String name) {
    return _insertProduct(id: id, name: name, hasImei: true);
  }

  Future<void> _insertProduct({
    required String id,
    required String name,
    required bool hasImei,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 11));
    await _appDatabase.insert(TableNames.productModels, <String, Object?>{
      'id': id,
      'name': name,
      'purchase_price': 5000,
      'sale_price': 6500,
      'has_imei': hasImei ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertSerializedStock({
    required String id,
    required String productModelId,
    required String imei1,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 11, 0, 1));
    await _appDatabase.insert(TableNames.serializedStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'imei1': imei1,
      'stock_status': 'in_stock',
      'cost_price': 5000,
      'selling_price': 6500,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> insertInventoryStock({
    required String id,
    required String productModelId,
    required int quantity,
    required int minQuantity,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 11, 0, 2));
    await _appDatabase.insert(TableNames.inventoryStock, <String, Object?>{
      'id': id,
      'product_model_id': productModelId,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'unit_cost': 100,
      'unit_price': 150,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> getInventoryQuantity(String productModelId) async {
    final rows = await _appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    return (rows.single['quantity'] as num).toInt();
  }

  Future<int> countAdjustmentsForProduct(String productModelId) async {
    final rows = await _appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.stockAdjustments} WHERE product_model_id = ?',
      <Object?>[productModelId],
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<int> countWriteOffAdjustments(String serializedStockId) async {
    final rows = await _appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.stockAdjustments} WHERE serialized_stock_id = ? AND adjustment_type = ?',
      <Object?>[serializedStockId, 'write_off'],
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<List<Map<String, Object?>>> getStockRows({String? search}) {
    return _appDatabase.database.rawQuery(
      '''
      SELECT pm.id, pm.name
      FROM ${TableNames.productModels} pm
      WHERE (? IS NULL OR pm.name LIKE '%' || ? || '%')
      LIMIT 200
      ''',
      <Object?>[search, search],
    );
  }

  Future<bool> tableExists(String tableName) async {
    final rows = await _appDatabase.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      <Object?>[tableName],
    );
    return rows.isNotEmpty;
  }

  Future<String?> latestAdjustmentNotes(String productModelId) async {
    final rows = await _appDatabase.database.rawQuery(
      '''
      SELECT notes
      FROM ${TableNames.stockAdjustments}
      WHERE product_model_id = ?
      ORDER BY created_at DESC
      LIMIT 1
      ''',
      <Object?>[productModelId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.single['notes'] as String?;
  }

  Future<bool> tryInsertDuplicateImei({
    required String id,
    required String productModelId,
    required String imei1,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 18, 11, 0, 3));
    try {
      await _appDatabase.insert(TableNames.serializedStock, <String, Object?>{
        'id': id,
        'product_model_id': productModelId,
        'imei1': imei1,
        'stock_status': 'in_stock',
        'cost_price': 5000,
        'selling_price': 6500,
        'created_at': now,
        'updated_at': now,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> countSerializedRows(String productModelId) async {
    final rows = await _appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${TableNames.serializedStock} WHERE product_model_id = ?',
      <Object?>[productModelId],
    );
    return (rows.single['count'] as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
