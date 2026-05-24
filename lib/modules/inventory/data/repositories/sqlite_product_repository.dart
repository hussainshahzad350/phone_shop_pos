import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/product_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/product_repository.dart';

class SqliteProductRepository
    with BaseRepositoryGuard
    implements ProductRepository {
  SqliteProductRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<ProductEntity>> createProduct(ProductEntity product) {
    return guard<ProductEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final model = ProductModel(
        id: product.id.isNotEmpty ? product.id : IdHelpers.newId(prefix: 'prd'),
        name: product.name,
        brand: product.brand,
        category: product.category,
        sku: product.sku,
        barcode: product.barcode,
        minStockAlert: product.minStockAlert,
        purchasePrice: product.purchasePrice,
        salePrice: product.salePrice,
        hasImei: product.hasImei,
        isActive: product.isActive,
        createdAt: now,
        updatedAt: now,
      );
      await _appDatabase.insert(TableNames.productModels, model.toMap());
      return model.toEntity();
    }, operation: 'create_product');
  }

  @override
  Future<Result<ProductEntity?>> getProductById(String id) {
    return guard<ProductEntity?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.productModels,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ProductModel.fromMap(rows.first).toEntity();
    }, operation: 'get_product_by_id');
  }

  @override
  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    bool? hasImei,
    bool? isActive,
    int limit = 50,
  }) {
    return guard<List<ProductEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer();
      if (isActive != null) {
        where.write('is_active = ?');
        args.add(isActive ? 1 : 0);
      }
      if (trimmed.isNotEmpty) {
        if (where.isNotEmpty) {
          where.write(' AND ');
        }
        where.write(
          '(name LIKE ? OR sku LIKE ? OR brand LIKE ? OR category LIKE ? OR barcode LIKE ?)',
        );
        final pq = '$trimmed%';
        final lq = '%$trimmed%';
        args
          ..add(pq)
          ..add(pq)
          ..add(lq)
          ..add(lq)
          ..add(lq);
      }
      if (hasImei != null) {
        if (where.isNotEmpty) {
          where.write(' AND ');
        }
        where.write('has_imei = ?');
        args.add(hasImei ? 1 : 0);
      }
      final rows = await QueryDiagnostics.trace(
        label: 'inventory.search_products',
        action: () => _appDatabase.queryTable(
          TableNames.productModels,
          where: where.isEmpty ? null : where.toString(),
          whereArgs: args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
      );
      return rows
          .map(ProductModel.fromMap)
          .map((m) => m.toEntity())
          .toList(growable: false);
    }, operation: 'search_products');
  }

  @override
  Future<Result<void>> updateProduct(ProductEntity product) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.productModels,
        <String, Object?>{
          'name': product.name,
          'brand': product.brand,
          'category': product.category,
          'sku': product.sku,
          'barcode': product.barcode,
          'min_stock_alert': product.minStockAlert,
          'purchase_price': product.purchasePrice,
          'sale_price': product.salePrice,
          'has_imei': product.hasImei ? 1 : 0,
          'is_active': product.isActive ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[product.id],
      );
    }, operation: 'update_product');
  }

  @override
  Future<Result<void>> deactivateProduct(String id) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.productModels,
        <String, Object?>{
          'is_active': 0,
          'updated_at': DateTimeHelpers.toSql(now)
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'deactivate_product');
  }

  @override
  Future<Result<void>> activateProduct(String id) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.productModels,
        <String, Object?>{
          'is_active': 1,
          'updated_at': DateTimeHelpers.toSql(now)
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'activate_product');
  }

  @override
  Future<Result<bool>> isSkuUnique(String sku, {String? excludeId}) {
    return guard<bool>(() async {
      final trimmed = sku.trim();
      if (trimmed.isEmpty) return true;
      final where = excludeId != null ? 'sku = ? AND id != ?' : 'sku = ?';
      final args = excludeId != null
          ? <Object?>[trimmed, excludeId]
          : <Object?>[trimmed];
      final rows = await _appDatabase.queryTable(
        TableNames.productModels,
        where: where,
        whereArgs: args,
        limit: 1,
      );
      return rows.isEmpty;
    }, operation: 'is_sku_unique');
  }
}
