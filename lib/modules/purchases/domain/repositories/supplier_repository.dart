import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';

abstract class SupplierRepository extends BaseRepository {
  Future<Result<SupplierEntity>> createSupplier(SupplierEntity supplier);

  Future<Result<SupplierEntity?>> getSupplierById(String id);

  Future<Result<List<SupplierEntity>>> searchSuppliers(
    String query, {
    bool? isActive,
    int limit = 100,
  });

  Future<Result<void>> updateSupplier(SupplierEntity supplier);

  Future<Result<void>> setActive(String id, {required bool active});
}
