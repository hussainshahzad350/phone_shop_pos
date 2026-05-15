import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/inventory_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/serialized_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_summary_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/inventory_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteInventoryRepository
    with BaseRepositoryGuard
    implements InventoryRepository {
  SqliteInventoryRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');

  final AppDatabase _appDatabase;

  @override
  Future<Result<SerializedStockEntity>> addSerializedStock(
    SerializedStockEntity stock,
  ) {
    return guard<SerializedStockEntity>(() async {
      final model = SerializedStockModel.fromEntity(stock);
      await _appDatabase.insert(TableNames.serializedStock, model.toMap());
      return model.toEntity();
    }, operation: 'add_serialized_stock');
  }

  @override
  Future<Result<List<SerializedStockEntity>>> searchSerializedByImei(
    String imei, {
    int limit = 20,
  }) {
    return guard<List<SerializedStockEntity>>(() async {
      final trimmed = imei.trim();
      final usePrefix =
          trimmed.isNotEmpty && _digitsOnlyPattern.hasMatch(trimmed);
      final searchQuery = usePrefix ? '$trimmed%' : '%$trimmed%';
      final rows = await QueryDiagnostics.trace(
        label: 'inventory.search_serialized_by_imei',
        action: () => _appDatabase.queryTable(
          TableNames.serializedStock,
          where: 'imei1 LIKE ? OR imei2 LIKE ? OR serial_number LIKE ?',
          whereArgs: <Object?>[searchQuery, searchQuery, searchQuery],
          orderBy: 'created_at DESC',
          limit: limit,
        ),
      );
      return rows
          .map(SerializedStockModel.fromMap)
          .map((m) => m.toEntity())
          .toList(growable: false);
    }, operation: 'search_serialized_by_imei');
  }

  @override
  Future<Result<void>> updateSerializedStockStatus({
    required String stockId,
    required SerializedStockStatus status,
  }) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.serializedStock,
        <String, Object?>{
          'stock_status': status.value,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[stockId],
      );
    }, operation: 'update_serialized_stock_status');
  }

  @override
  Future<Result<InventoryStockModel?>> getInventoryStockByProduct(
    String productModelId,
  ) {
    return guard<InventoryStockModel?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>[productModelId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return InventoryStockModel.fromMap(rows.first);
    }, operation: 'get_inventory_stock_by_product');
  }

  @override
  Future<Result<void>> upsertInventoryStock(InventoryStockModel stock) {
    return guard<void>(() async {
      await _appDatabase.insert(
        TableNames.inventoryStock,
        stock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }, operation: 'upsert_inventory_stock');
  }

  @override
  Future<Result<int>> adjustInventoryQuantity({
    required String productModelId,
    required int delta,
  }) {
    return guard<int>(() async {
      final now = DateTimeHelpers.nowUtc();
      final rows = await _appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>[productModelId],
        limit: 1,
      );

      if (rows.isEmpty) {
        if (delta < 0) {
          throw StateError('No inventory stock record found for product.');
        }
        final newModel = InventoryStockModel(
          id: IdHelpers.newId(prefix: 'stk'),
          productModelId: productModelId,
          quantity: delta,
          minQuantity: 0,
          unitCost: 0,
          unitPrice: 0,
          createdAt: now,
          updatedAt: now,
        );
        await _appDatabase.insert(
          TableNames.inventoryStock,
          newModel.toMap(),
        );
        return delta;
      }

      final current = rows.first['quantity'] as int;
      final newQty = current + delta;
      if (newQty < 0) {
        throw StateError('Insufficient stock quantity.');
      }
      await _appDatabase.update(
        TableNames.inventoryStock,
        <String, Object?>{
          'quantity': newQty,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'product_model_id = ?',
        whereArgs: <Object?>[productModelId],
      );
      return newQty;
    }, operation: 'adjust_inventory_quantity');
  }

  @override
  Future<Result<List<StockRowEntity>>> getStockRows({
    String? searchQuery,
    SerializedStockStatus? serializedStatusFilter,
    bool? hasImeiFilter,
    int limit = 200,
  }) {
    return guard<List<StockRowEntity>>(() async {
      final args = <Object?>[];
      final serializedWhere = StringBuffer('pm.is_active = 1');
      final quantityWhere = StringBuffer('pm.is_active = 1');

      final trimmed = searchQuery?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        serializedWhere.write(
          ' AND (pm.name LIKE ? OR pm.sku LIKE ? OR pm.brand LIKE ?'
          ' OR ss.imei1 LIKE ? OR ss.imei2 LIKE ?)',
        );
        quantityWhere.write(
          ' AND (pm.name LIKE ? OR pm.sku LIKE ? OR pm.brand LIKE ?)',
        );
      }

      if (serializedStatusFilter != null) {
        serializedWhere.write(' AND ss.stock_status = ?');
      }

      final showSerialized = hasImeiFilter == null || hasImeiFilter == true;
      final showQuantity = hasImeiFilter == null || hasImeiFilter == false;

      final parts = <String>[];

      if (showSerialized) {
        parts.add('''
SELECT
  'serialized' AS row_type,
  pm.id AS product_model_id,
  pm.name,
  pm.brand,
  pm.category,
  pm.sku,
  ss.id AS serialized_stock_id,
  ss.imei1,
  ss.imei2,
  ss.serial_number,
  ss.stock_status,
  ss.cost_price,
  ss.selling_price,
  NULL AS inventory_stock_id,
  NULL AS quantity,
  NULL AS min_quantity,
  NULL AS unit_cost,
  NULL AS unit_price,
  NULL AS location
FROM ${TableNames.serializedStock} ss
JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
WHERE ${serializedWhere.toString()}''');

        if (trimmed.isNotEmpty) {
          final likeQuery = '%$trimmed%';
          args
            ..add(likeQuery)
            ..add(likeQuery)
            ..add(likeQuery)
            ..add(likeQuery)
            ..add(likeQuery);
        }
        if (serializedStatusFilter != null) {
          args.add(serializedStatusFilter.value);
        }
      }

      if (showQuantity) {
        parts.add('''
SELECT
  'quantity' AS row_type,
  pm.id AS product_model_id,
  pm.name,
  pm.brand,
  pm.category,
  pm.sku,
  NULL AS serialized_stock_id,
  NULL AS imei1,
  NULL AS imei2,
  NULL AS serial_number,
  NULL AS stock_status,
  NULL AS cost_price,
  NULL AS selling_price,
  ist.id AS inventory_stock_id,
  ist.quantity,
  ist.min_quantity,
  ist.unit_cost,
  ist.unit_price,
  ist.location
FROM ${TableNames.inventoryStock} ist
JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
WHERE ${quantityWhere.toString()}''');

        if (trimmed.isNotEmpty) {
          final likeQuery = '%$trimmed%';
          args
            ..add(likeQuery)
            ..add(likeQuery)
            ..add(likeQuery);
        }
      }

      if (parts.isEmpty) {
        return const <StockRowEntity>[];
      }

      final sql =
          '${parts.join('\nUNION ALL\n')}\nORDER BY name COLLATE NOCASE ASC\nLIMIT $limit';

      final rows = await QueryDiagnostics.trace(
        label: 'inventory.get_stock_rows',
        action: () => _appDatabase.database.rawQuery(sql, args),
      );
      return rows.map(_rowToStockRowEntity).toList(growable: false);
    }, operation: 'get_stock_rows');
  }

  @override
  Future<Result<InventorySummaryEntity>> getInventorySummary() {
    return guard<InventorySummaryEntity>(() async {
      final db = _appDatabase.database;

      final phoneCountRows = await db.rawQuery('''
        SELECT
          COUNT(*) AS total,
          SUM(CASE WHEN stock_status = 'in_stock' THEN 1 ELSE 0 END) AS in_stock,
          SUM(CASE WHEN stock_status = 'sold' THEN 1 ELSE 0 END) AS sold,
          SUM(CASE WHEN stock_status = 'reserved' THEN 1 ELSE 0 END) AS reserved,
          SUM(CASE WHEN stock_status = 'in_stock' THEN cost_price ELSE 0 END) AS phone_value
        FROM ${TableNames.serializedStock}
      ''');

      final accessoryRows = await db.rawQuery('''
        SELECT
          COUNT(*) AS variants,
          SUM(ist.quantity) AS units,
          SUM(ist.quantity * ist.unit_cost) AS accessory_value,
          SUM(CASE WHEN ist.quantity <= ist.min_quantity THEN 1 ELSE 0 END) AS low_stock
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND pm.has_imei = 0
      ''');

      final phoneRow = phoneCountRows.first;
      final accRow = accessoryRows.first;

      final phoneValue = (phoneRow['phone_value'] as num?)?.toDouble() ?? 0.0;
      final accessoryValue =
          (accRow['accessory_value'] as num?)?.toDouble() ?? 0.0;

      return InventorySummaryEntity(
        totalPhones: (phoneRow['total'] as num?)?.toInt() ?? 0,
        inStockPhones: (phoneRow['in_stock'] as num?)?.toInt() ?? 0,
        soldPhones: (phoneRow['sold'] as num?)?.toInt() ?? 0,
        reservedPhones: (phoneRow['reserved'] as num?)?.toInt() ?? 0,
        totalAccessoryVariants: (accRow['variants'] as num?)?.toInt() ?? 0,
        totalAccessoryUnits: (accRow['units'] as num?)?.toInt() ?? 0,
        lowStockCount: (accRow['low_stock'] as num?)?.toInt() ?? 0,
        totalStockValue: phoneValue + accessoryValue,
      );
    }, operation: 'get_inventory_summary');
  }

  @override
  Future<Result<List<StockRowEntity>>> getLowStockRows() {
    return guard<List<StockRowEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery('''
        SELECT
          'quantity' AS row_type,
          pm.id AS product_model_id,
          pm.name,
          pm.brand,
          pm.category,
          pm.sku,
          NULL AS serialized_stock_id,
          NULL AS imei1,
          NULL AS imei2,
          NULL AS serial_number,
          NULL AS stock_status,
          NULL AS cost_price,
          NULL AS selling_price,
          ist.id AS inventory_stock_id,
          ist.quantity,
          ist.min_quantity,
          ist.unit_cost,
          ist.unit_price,
          ist.location
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND ist.quantity <= ist.min_quantity
        ORDER BY pm.name COLLATE NOCASE ASC
      ''');
      return rows.map(_rowToStockRowEntity).toList(growable: false);
    }, operation: 'get_low_stock_rows');
  }

  StockRowEntity _rowToStockRowEntity(Map<String, Object?> row) {
    final rowType = row['row_type'] as String;
    if (rowType == 'serialized') {
      return StockRowEntity(
        type: StockRowType.serialized,
        productModelId: row['product_model_id'] as String,
        productName: row['name'] as String,
        brand: row['brand'] as String?,
        category: row['category'] as String?,
        sku: row['sku'] as String?,
        serializedStockId: row['serialized_stock_id'] as String?,
        imei1: row['imei1'] as String?,
        imei2: row['imei2'] as String?,
        serialNumber: row['serial_number'] as String?,
        serializedStatus: row['stock_status'] != null
            ? SerializedStockStatus.fromValue(row['stock_status'] as String)
            : null,
        costPrice: (row['cost_price'] as num?)?.toDouble(),
        sellingPrice: (row['selling_price'] as num?)?.toDouble(),
      );
    }
    return StockRowEntity(
      type: StockRowType.quantity,
      productModelId: row['product_model_id'] as String,
      productName: row['name'] as String,
      brand: row['brand'] as String?,
      category: row['category'] as String?,
      sku: row['sku'] as String?,
      inventoryStockId: row['inventory_stock_id'] as String?,
      quantity: (row['quantity'] as num?)?.toInt(),
      minQuantity: (row['min_quantity'] as num?)?.toInt(),
      unitCost: (row['unit_cost'] as num?)?.toDouble(),
      unitPrice: (row['unit_price'] as num?)?.toDouble(),
      location: row['location'] as String?,
    );
  }
}
