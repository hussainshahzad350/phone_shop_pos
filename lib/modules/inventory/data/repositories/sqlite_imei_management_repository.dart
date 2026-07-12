import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/audit_logger.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/imei_bulk_parser.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/bulk_imei_import_summary.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/imei_management_entry.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/imei_management_repository.dart';

class SqliteImeiManagementRepository
    with BaseRepositoryGuard
    implements ImeiManagementRepository {
  SqliteImeiManagementRepository({required AppDatabase appDatabase})
      : _db = appDatabase;

  final AppDatabase _db;

  @override
  Future<Result<List<ImeiManagementEntry>>> getImeisForModel(
    String productModelId,
  ) {
    return guard<List<ImeiManagementEntry>>(() async {
      final rows = await _db.database.rawQuery(
        '''
        SELECT
          ss.id AS stock_id,
          ss.imei1,
          ss.imei2,
          ss.stock_status,
          ss.cost_price,
          ss.purchase_date,
          ss.created_at,
          ss.supplier_id,
          sup.name AS supplier_name
        FROM ${TableNames.serializedStock} ss
        LEFT JOIN ${TableNames.suppliers} sup ON sup.id = ss.supplier_id
        WHERE ss.product_model_id = ?
        ORDER BY ss.purchase_date DESC, ss.created_at DESC
        ''',
        <Object?>[productModelId],
      );

      return rows.map(_rowToEntry).toList(growable: false);
    }, operation: 'get_imeis_for_model');
  }

  @override
  Future<Result<void>> addImei({
    required String productModelId,
    required String imei1,
    String? imei2,
    DateTime? purchaseDate,
    required double costPrice,
    String? supplierId,
  }) {
    return guard<void>(() async {
      final i1 = imei1.trim();
      final i2 = imei2?.trim();

      if (!FieldValidators.isValidImei(i1)) {
        throw StateError('IMEI must be 14–15 digits.');
      }
      if (i2 != null && i2.isNotEmpty) {
        if (!FieldValidators.isValidImei(i2)) {
          throw StateError('Secondary IMEI must be 14–15 digits.');
        }
        if (i1 == i2) {
          throw StateError('Primary and secondary IMEI must be different.');
        }
      }
      final normalizedI2 = (i2 != null && i2.isNotEmpty) ? i2 : null;

      // Duplicate check across both IMEI columns
      for (final value in <String>{i1, if (normalizedI2 != null) normalizedI2}) {
        final existing = await _db.queryTable(
          TableNames.serializedStock,
          where: 'imei1 = ? OR imei2 = ?',
          whereArgs: <Object?>[value, value],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError('IMEI already exists in stock: $value');
        }
      }

      final now = DateTimeHelpers.nowUtc();
      final effectivePurchaseDate = purchaseDate ?? now;

      await _db.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ss'),
        'product_model_id': productModelId,
        'imei1': i1,
        'imei2': normalizedI2,
        'stock_status': SerializedStockStatus.inStock.value,
        'cost_price': costPrice,
        'purchase_date': DateTimeHelpers.toSql(effectivePurchaseDate),
        'supplier_id': supplierId,
        'created_at': DateTimeHelpers.toSql(now),
        'updated_at': DateTimeHelpers.toSql(now),
      });
    }, operation: 'add_imei');
  }

  @override
  Future<Result<BulkImeiImportSummary>> addImeisBulk({
    required String productModelId,
    required List<ParsedImeiLine> entries,
    required DateTime purchaseDate,
    required double costPrice,
    String? supplierId,
  }) {
    return guard<BulkImeiImportSummary>(() async {
      final duplicates = <String>[];
      final failed = <BulkImeiImportFailure>[];
      var added = 0;

      await _db.runInTransaction<void>((transaction) async {
        // Track values added within this same batch so intra-batch repeats
        // are also caught, not just ones already in the database.
        final seenThisBatch = <String>{};

        for (final entry in entries) {
          final i1 = entry.imei1.trim();
          final i2 = entry.imei2?.trim();
          final normalizedI2 = (i2 != null && i2.isNotEmpty) ? i2 : null;

          if (!FieldValidators.isValidImei(i1)) {
            failed.add(BulkImeiImportFailure(
              imei: i1,
              reason: 'Must be 14–15 digits',
            ));
            continue;
          }
          if (normalizedI2 != null &&
              !FieldValidators.isValidImei(normalizedI2)) {
            failed.add(BulkImeiImportFailure(
              imei: normalizedI2,
              reason: 'Secondary IMEI must be 14–15 digits',
            ));
            continue;
          }

          if (seenThisBatch.contains(i1)) {
            duplicates.add(i1);
            continue;
          }
          if (normalizedI2 != null && seenThisBatch.contains(normalizedI2)) {
            duplicates.add(normalizedI2);
            continue;
          }

          final existing = await transaction.query(
            TableNames.serializedStock,
            where: 'imei1 = ? OR imei2 = ?'
                '${normalizedI2 != null ? ' OR imei1 = ? OR imei2 = ?' : ''}',
            whereArgs: normalizedI2 != null
                ? <Object?>[i1, i1, normalizedI2, normalizedI2]
                : <Object?>[i1, i1],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            final match = existing.first;
            final matchedValue = (match['imei1'] == i1 || match['imei2'] == i1)
                ? i1
                : (normalizedI2 ?? i1);
            duplicates.add(matchedValue);
            continue;
          }

          final now = DateTimeHelpers.nowUtc();
          await transaction.insert(TableNames.serializedStock, <String, Object?>{
            'id': IdHelpers.newId(prefix: 'ss'),
            'product_model_id': productModelId,
            'imei1': i1,
            'imei2': normalizedI2,
            'serial_number': entry.serialNumber,
            'stock_status': SerializedStockStatus.inStock.value,
            'cost_price': costPrice,
            'purchase_date': DateTimeHelpers.toSql(purchaseDate),
            'supplier_id': supplierId,
            'created_at': DateTimeHelpers.toSql(now),
            'updated_at': DateTimeHelpers.toSql(now),
          });

          seenThisBatch.add(i1);
          if (normalizedI2 != null) {
            seenThisBatch.add(normalizedI2);
          }
          added++;
        }

        await AuditLogger.record(
          transaction,
          action: 'bulk_add_imei',
          entityId: productModelId,
          details: 'Added $added of ${entries.length} scanned IMEIs '
              '(${duplicates.length} duplicate(s), ${failed.length} failed).',
        );
      });

      return BulkImeiImportSummary(
        totalScanned: entries.length,
        added: added,
        duplicates: duplicates,
        failed: failed,
      );
    }, operation: 'add_imeis_bulk');
  }

  @override
  Future<Result<void>> deleteImei(String stockId) {
    return guard<void>(() async {
      // Verify it exists and is in_stock before deleting
      final rows = await _db.queryTable(
        TableNames.serializedStock,
        where: 'id = ?',
        whereArgs: <Object?>[stockId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('IMEI record not found.');
      }
      final status = rows.first['stock_status'] as String?;
      if (status != SerializedStockStatus.inStock.value) {
        throw StateError(
          'Only in-stock IMEIs can be deleted. Current status: $status',
        );
      }

      await _db.delete(
        TableNames.serializedStock,
        where: 'id = ?',
        whereArgs: <Object?>[stockId],
      );
    }, operation: 'delete_imei');
  }

  @override
  Future<Result<void>> updatePurchaseInfo({
    required String stockId,
    DateTime? purchaseDate,
    required double costPrice,
    String? supplierId,
  }) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _db.update(
        TableNames.serializedStock,
        <String, Object?>{
          if (purchaseDate != null)
            'purchase_date': DateTimeHelpers.toSql(purchaseDate),
          'cost_price': costPrice,
          'supplier_id': supplierId,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[stockId],
      );
    }, operation: 'update_purchase_info');
  }

  ImeiManagementEntry _rowToEntry(Map<String, Object?> row) {
    final statusStr = row['stock_status'] as String? ?? 'in_stock';
    final purchaseDateStr = row['purchase_date'] as String?;
    final createdAtStr = row['created_at'] as String? ?? '';

    return ImeiManagementEntry(
      stockId: row['stock_id'] as String,
      imei1: row['imei1'] as String,
      imei2: row['imei2'] as String?,
      stockStatus: SerializedStockStatus.fromValue(statusStr),
      costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
      purchaseDate: purchaseDateStr != null
          ? DateTimeHelpers.fromSql(purchaseDateStr)
          : null,
      createdAt: DateTimeHelpers.fromSql(createdAtStr),
      supplierId: row['supplier_id'] as String?,
      supplierName: row['supplier_name'] as String?,
    );
  }
}
