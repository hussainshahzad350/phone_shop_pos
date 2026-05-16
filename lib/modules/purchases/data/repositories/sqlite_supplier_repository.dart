import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/supplier_model.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/supplier_repository.dart';

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
}
