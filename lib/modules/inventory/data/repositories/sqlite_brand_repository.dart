import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/brand_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/brand_repository.dart';

class SqliteBrandRepository
    with BaseRepositoryGuard
    implements BrandRepository {
  SqliteBrandRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<BrandEntity>> createBrand(BrandEntity brand) {
    return guard<BrandEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final model = BrandModel(
        id: brand.id.isNotEmpty ? brand.id : IdHelpers.newId(prefix: 'brn'),
        name: brand.name,
        isActive: brand.isActive,
        createdAt: now,
        updatedAt: now,
      );
      await _appDatabase.insert(TableNames.brands, model.toMap());
      return model.toEntity();
    }, operation: 'create_brand');
  }

  @override
  Future<Result<List<BrandEntity>>> searchBrands(
    String query, {
    bool? isActive,
    int limit = 100,
  }) {
    return guard<List<BrandEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer();
      if (isActive != null) {
        where.write('is_active = ?');
        args.add(isActive ? 1 : 0);
      }
      if (trimmed.isNotEmpty) {
        if (where.isNotEmpty) where.write(' AND ');
        where.write('name LIKE ?');
        args.add('%$trimmed%');
      }
      final rows = await QueryDiagnostics.trace(
        label: 'brands.search',
        action: () => _appDatabase.queryTable(
          TableNames.brands,
          where: where.isEmpty ? null : where.toString(),
          whereArgs: args.isEmpty ? null : args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
      );
      return rows
          .map(BrandModel.fromMap)
          .map((m) => m.toEntity())
          .toList(growable: false);
    }, operation: 'search_brands');
  }

  @override
  Future<Result<void>> updateBrand(BrandEntity brand) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.brands,
        <String, Object?>{
          'name': brand.name,
          'is_active': brand.isActive ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[brand.id],
      );
    }, operation: 'update_brand');
  }

  @override
  Future<Result<void>> setActive(String id, {required bool active}) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.brands,
        <String, Object?>{
          'is_active': active ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now)
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'set_brand_active');
  }

  @override
  Future<Result<bool>> isNameUnique(String name, {String? excludeId}) {
    return guard<bool>(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return true;
      final where = excludeId != null ? 'name = ? AND id != ?' : 'name = ?';
      final args = excludeId != null
          ? <Object?>[trimmed, excludeId]
          : <Object?>[trimmed];
      final rows = await _appDatabase.queryTable(TableNames.brands,
          where: where, whereArgs: args, limit: 1);
      return rows.isEmpty;
    }, operation: 'is_brand_name_unique');
  }
}
