import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/audit_logger.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/supplier_model.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_summary_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/supplier_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteSupplierRepository
    with BaseRepositoryGuard
    implements SupplierRepository {
  SqliteSupplierRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<SupplierEntity>> createSupplier(SupplierEntity supplier) {
    return guard<SupplierEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final model = SupplierModel(
        id: supplier.id.isNotEmpty
            ? supplier.id
            : IdHelpers.newId(prefix: 'sup'),
        name: supplier.name,
        contactPerson: supplier.contactPerson,
        phone: supplier.phone,
        email: supplier.email,
        address: supplier.address,
        notes: supplier.notes,
        isActive: supplier.isActive,
        createdAt: now,
        updatedAt: now,
      );
      await _appDatabase.insert(TableNames.suppliers, model.toMap());
      return model.toEntity();
    }, operation: 'create_supplier');
  }

  @override
  Future<Result<SupplierEntity?>> getSupplierById(String id) {
    return guard<SupplierEntity?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.suppliers,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SupplierModel.fromMap(rows.first).toEntity();
    }, operation: 'get_supplier_by_id');
  }

  @override
  Future<Result<List<SupplierEntity>>> searchSuppliers(
    String query, {
    bool? isActive,
    int limit = 100,
  }) {
    return guard<List<SupplierEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer();
      if (isActive != null) {
        where.write('is_active = ?');
        args.add(isActive ? 1 : 0);
      }
      if (trimmed.isNotEmpty) {
        if (where.isNotEmpty) where.write(' AND ');
        where.write('(name LIKE ? OR phone LIKE ? OR contact_person LIKE ?)');
        final lq = '%$trimmed%';
        args
          ..add(lq)
          ..add(lq)
          ..add(lq);
      }
      final rows = await QueryDiagnostics.trace(
        label: 'suppliers.search',
        action: () => _appDatabase.queryTable(
          TableNames.suppliers,
          where: where.isEmpty ? null : where.toString(),
          whereArgs: args.isEmpty ? null : args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
      );
      return rows
          .map(SupplierModel.fromMap)
          .map((m) => m.toEntity())
          .toList(growable: false);
    }, operation: 'search_suppliers');
  }

  @override
  Future<Result<void>> updateSupplier(SupplierEntity supplier) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.suppliers,
        <String, Object?>{
          'name': supplier.name,
          'contact_person': supplier.contactPerson,
          'phone': supplier.phone,
          'email': supplier.email,
          'address': supplier.address,
          'notes': supplier.notes,
          'is_active': supplier.isActive ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[supplier.id],
      );
    }, operation: 'update_supplier');
  }

  @override
  Future<Result<void>> setActive(String id, {required bool active}) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.suppliers,
        <String, Object?>{
          'is_active': active ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now)
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'set_supplier_active');
  }

  @override
  Future<Result<void>> deleteSupplier(String id) {
    return guard<void>(() async {
      await _appDatabase.runInTransaction<void>((transaction) async {
        final stockCount = await _countWhere(
          transaction,
          TableNames.serializedStock,
          'supplier_id = ?',
          <Object?>[id],
        );
        final purchaseCount = await _countWhere(
          transaction,
          TableNames.purchases,
          'supplier_id = ?',
          <Object?>[id],
        );
        final productCount = await _countWhere(
          transaction,
          TableNames.productModels,
          'supplier_id = ?',
          <Object?>[id],
        );
        final linked = stockCount + purchaseCount + productCount;
        if (linked > 0) {
          throw StateError(
            'Cannot delete supplier: $linked linked record(s) '
            '($stockCount inventory item(s), $purchaseCount purchase(s), '
            '$productCount product(s)). Archive it instead.',
          );
        }
        await transaction.delete(
          TableNames.suppliers,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await AuditLogger.record(
          transaction,
          action: 'delete_supplier',
          entityId: id,
          details: 'Hard-deleted supplier with no linked records.',
        );
      });
    }, operation: 'delete_supplier');
  }

  Future<int> _countWhere(
    DatabaseExecutor db,
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $table WHERE $where',
      whereArgs,
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Result<List<SupplierSummaryEntity>>> getSupplierSummaries({
    String query = '',
  }) {
    return guard<List<SupplierSummaryEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer('s.is_active = 1');
      if (trimmed.isNotEmpty) {
        where.write(' AND (s.name LIKE ? OR s.phone LIKE ?)');
        final lq = '%$trimmed%';
        args
          ..add(lq)
          ..add(lq);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'suppliers.get_summaries',
        action: () => _appDatabase.database.rawQuery(
          '''
          SELECT
            s.id,
            s.name,
            s.phone,
            s.email,
            (SELECT COUNT(*) FROM ${TableNames.purchases} p WHERE p.supplier_id = s.id) AS total_purchases,
            (SELECT COUNT(*) FROM ${TableNames.serializedStock} ss
              WHERE ss.supplier_id = s.id AND ss.stock_status = 'in_stock') AS current_stock,
            (SELECT COALESCE(SUM(p.total), 0) FROM ${TableNames.purchases} p WHERE p.supplier_id = s.id) AS total_value,
            (SELECT MAX(p.purchase_date) FROM ${TableNames.purchases} p WHERE p.supplier_id = s.id) AS last_purchase_date
          FROM ${TableNames.suppliers} s
          WHERE ${where.toString()}
          ORDER BY s.name COLLATE NOCASE ASC
          ''',
          args,
        ),
      );

      return rows.map((row) {
        final lastPurchaseRaw = row['last_purchase_date'] as String?;
        return SupplierSummaryEntity(
          supplierId: row['id'] as String,
          name: row['name'] as String,
          phone: row['phone'] as String?,
          email: row['email'] as String?,
          totalPurchases: (row['total_purchases'] as num?)?.toInt() ?? 0,
          currentStock: (row['current_stock'] as num?)?.toInt() ?? 0,
          totalPurchaseValue: (row['total_value'] as num?)?.toDouble() ?? 0,
          lastPurchaseDate: lastPurchaseRaw != null
              ? DateTimeHelpers.fromSql(lastPurchaseRaw)
              : null,
        );
      }).toList(growable: false);
    }, operation: 'get_supplier_summaries');
  }

  @override
  Future<Result<List<SupplierPurchaseHistoryRowEntity>>>
      getSupplierPurchaseHistory(String supplierId) {
    return guard<List<SupplierPurchaseHistoryRowEntity>>(() async {
      final rows = await QueryDiagnostics.trace(
        label: 'suppliers.get_purchase_history',
        action: () => _appDatabase.database.rawQuery(
          '''
          SELECT
            pm.name AS product_name,
            pm.brand,
            ss.imei1,
            p.purchase_date,
            pi.unit_cost,
            ss.stock_status,
            p.invoice_number,
            pi.quantity
          FROM ${TableNames.purchaseItems} pi
          JOIN ${TableNames.purchases} p ON p.id = pi.purchase_id
          JOIN ${TableNames.productModels} pm ON pm.id = pi.product_model_id
          LEFT JOIN ${TableNames.serializedStock} ss ON ss.id = pi.serialized_stock_id
          WHERE p.supplier_id = ?
          ORDER BY p.purchase_date DESC
          ''',
          <Object?>[supplierId],
        ),
      );

      return rows.map((row) {
        final purchaseDateRaw = row['purchase_date'] as String?;
        return SupplierPurchaseHistoryRowEntity(
          productName: row['product_name'] as String? ?? '-',
          brand: row['brand'] as String?,
          imei: row['imei1'] as String?,
          purchaseDate: purchaseDateRaw != null
              ? DateTimeHelpers.fromSql(purchaseDateRaw)
              : null,
          purchasePrice: (row['unit_cost'] as num?)?.toDouble(),
          currentStatus: row['stock_status'] as String?,
          invoiceNumber: row['invoice_number'] as String?,
          quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        );
      }).toList(growable: false);
    }, operation: 'get_supplier_purchase_history');
  }
}
