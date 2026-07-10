import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';

abstract class ProductRepository extends BaseRepository {
  Future<Result<ProductEntity>> createProduct(ProductEntity product);

  Future<Result<ProductEntity?>> getProductById(String id);

  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    bool? hasImei,
    bool? isActive,
    int limit = 50,
  });

  Future<Result<void>> updateProduct(ProductEntity product);

  Future<Result<void>> deactivateProduct(String id);

  Future<Result<void>> activateProduct(String id);

  Future<Result<bool>> isSkuUnique(String sku, {String? excludeId});

  /// Returns true when no other product shares [name] (case-insensitive).
  /// Pass [excludeId] to ignore the product being edited.
  Future<Result<bool>> isNameUnique(String name, {String? excludeId});
}
