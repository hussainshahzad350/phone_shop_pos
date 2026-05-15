import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';

class InventoryService {
  const InventoryService({required SqliteInventoryRepository repository})
      : _repository = repository;

  final SqliteInventoryRepository _repository;

  Future<Result<List<StockRowEntity>>> getStockRows({
    String? searchQuery,
    SerializedStockStatus? serializedStatusFilter,
    bool? hasImeiFilter,
    int limit = 200,
  }) {
    return _repository.getStockRows(
      searchQuery: searchQuery,
      serializedStatusFilter: serializedStatusFilter,
      hasImeiFilter: hasImeiFilter,
      limit: limit,
    );
  }

  Future<Result<InventorySummaryEntity>> getInventorySummary() {
    return _repository.getInventorySummary();
  }

  Future<Result<List<StockRowEntity>>> getLowStockRows() {
    return _repository.getLowStockRows();
  }

  Future<Result<List<SerializedStockEntity>>> searchByImei(String imei) {
    return _repository.searchSerializedByImei(imei);
  }
}
