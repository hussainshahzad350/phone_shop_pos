import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_summary_entity.dart';

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

  /// Permanently deletes a supplier. Fails with a descriptive message if any
  /// inventory or purchase record still references it — archive instead in
  /// that case. Never leaves orphan references.
  Future<Result<void>> deleteSupplier(String id);

  /// Aggregate purchase/stock summary per supplier, for the Supplier
  /// Information list screen. Computed at query time from `purchases` and
  /// `serialized_stock` — no persisted aggregate table.
  Future<Result<List<SupplierSummaryEntity>>> getSupplierSummaries({
    String query = '',
  });

  /// Full purchase/inventory history for one supplier, for the Supplier
  /// Information detail screen.
  Future<Result<List<SupplierPurchaseHistoryRowEntity>>>
      getSupplierPurchaseHistory(String supplierId);
}
