import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';

abstract class InventoryRepository extends BaseRepository {
  Future<Result<SerializedStockEntity>> addSerializedStock(
    SerializedStockEntity stock,
  );

  Future<Result<List<SerializedStockEntity>>> searchSerializedByImei(
    String imei, {
    int limit = 20,
  });

  Future<Result<void>> updateSerializedStockStatus({
    required String stockId,
    required SerializedStockStatus status,
  });

  /// Loads a single serialized unit by its id (for editing its details).
  Future<Result<SerializedStockEntity?>> getSerializedStockById(String id);

  /// Persists edits to a serialized unit's details (cost, selling price,
  /// condition, status, buy date, notes). IMEI identity is not changed here.
  Future<Result<void>> updateSerializedStock(SerializedStockEntity stock);

  Future<Result<InventoryStockEntity?>> getInventoryStockByProduct(
    String productModelId,
  );

  Future<Result<void>> upsertInventoryStock(InventoryStockEntity stock);

  Future<Result<int>> adjustInventoryQuantity({
    required String productModelId,
    required int delta,
  });

  Future<Result<List<StockRowEntity>>> getStockRows({
    String? searchQuery,
    SerializedStockStatus? serializedStatusFilter,
    bool? hasImeiFilter,
    int limit = 200,
  });

  Future<Result<InventorySummaryEntity>> getInventorySummary();

  Future<Result<List<StockRowEntity>>> getLowStockRows();
}
