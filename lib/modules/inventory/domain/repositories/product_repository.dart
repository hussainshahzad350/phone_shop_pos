import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';

abstract class ProductRepository extends BaseRepository {
  Future<Result<ProductEntity>> createProduct(ProductEntity product);

  Future<Result<ProductEntity?>> getProductById(String id);

  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    bool? hasImei,
    int limit = 50,
  });

  Future<Result<void>> updateProduct(ProductEntity product);

  Future<Result<void>> deactivateProduct(String id);
}
