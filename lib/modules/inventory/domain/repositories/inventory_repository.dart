import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/inventory_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';

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

  Future<Result<InventoryStockModel?>> getInventoryStockByProduct(
    String productModelId,
  );

  Future<Result<void>> upsertInventoryStock(InventoryStockModel stock);

  Future<Result<int>> adjustInventoryQuantity({
    required String productModelId,
    required int delta,
  });
}
