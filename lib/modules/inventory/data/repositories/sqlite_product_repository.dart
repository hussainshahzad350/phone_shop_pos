import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
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
      if (rows.isEmpty) {
        return null;
      }
      return ProductModel.fromMap(rows.first).toEntity();
    }, operation: 'get_product_by_id');
  }

  @override
  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    bool? hasImei,
    int limit = 50,
  }) {
    return guard<List<ProductEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer('is_active = 1');

      if (trimmed.isNotEmpty) {
        where.write(
          ' AND (name LIKE ? OR sku LIKE ? OR brand LIKE ? OR category LIKE ?)',
        );
        final likeQuery = '%$trimmed%';
        args
          ..add(likeQuery)
          ..add(likeQuery)
          ..add(likeQuery)
          ..add(likeQuery);
      }

      if (hasImei != null) {
        where.write(' AND has_imei = ?');
        args.add(hasImei ? 1 : 0);
      }

      final rows = await _appDatabase.queryTable(
        TableNames.productModels,
        where: where.toString(),
        whereArgs: args,
        orderBy: 'name COLLATE NOCASE ASC',
        limit: limit,
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
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'deactivate_product');
  }
}
