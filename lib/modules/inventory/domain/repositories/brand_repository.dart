import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';

abstract class BrandRepository extends BaseRepository {
  Future<Result<BrandEntity>> createBrand(BrandEntity brand);

  Future<Result<List<BrandEntity>>> searchBrands(
    String query, {
    bool? isActive,
    int limit = 100,
  });

  Future<Result<void>> updateBrand(BrandEntity brand);

  Future<Result<void>> setActive(String id, {required bool active});

  Future<Result<bool>> isNameUnique(String name, {String? excludeId});
}
