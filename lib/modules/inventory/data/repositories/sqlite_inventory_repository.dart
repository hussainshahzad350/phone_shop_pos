import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/inventory_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/serialized_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/inventory_stock_entity.dart';
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
      final imei1 = stock.imei1.trim();
      final imei2 = _normalizeOptional(stock.imei2);
      if (imei1.isEmpty || !FieldValidators.isValidImei(imei1)) {
        throw StateError('Primary IMEI must be 14–15 digits.');
      }
      if (imei2 != null) {
        if (!FieldValidators.isValidImei(imei2)) {
          throw StateError('Secondary IMEI must be 14–15 digits.');
        }
        if (imei1 == imei2) {
          throw StateError('Primary and secondary IMEI must be different.');
        }
      }

      final imeiValues = <String>{imei1, if (imei2 != null) imei2};
      for (final value in imeiValues) {
        final existing = await _appDatabase.queryTable(
          TableNames.serializedStock,
          where: 'imei1 = ? OR imei2 = ?',
          whereArgs: <Object?>[value, value],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError('IMEI already exists in stock: $value');
        }
      }

      final model = SerializedStockModel.fromEntity(
        SerializedStockEntity(
          id: stock.id,
          productModelId: stock.productModelId,
          imei1: imei1,
          imei2: imei2,
          serialNumber: _normalizeOptional(stock.serialNumber),
          stockStatus: stock.stockStatus,
          costPrice: stock.costPrice,
          createdAt: stock.createdAt,
          updatedAt: stock.updatedAt,
          sellingPrice: stock.sellingPrice,
          supplierId: stock.supplierId,
          notes: stock.notes,
          condition: stock.condition,
          sellerName: stock.sellerName,
          sellerIdCard: stock.sellerIdCard,
          sellerAddress: stock.sellerAddress,
          remainingWarranty: stock.remainingWarranty,
          accessories: stock.accessories,
          phoneConditionNotes: stock.phoneConditionNotes,
          sellerPhone: stock.sellerPhone,
        ),
      );
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
  Future<Result<InventoryStockEntity?>> getInventoryStockByProduct(
    String productModelId,
  ) {
    return guard<InventoryStockEntity?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>[productModelId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return InventoryStockModel.fromMap(rows.first).toEntity();
    }, operation: 'get_inventory_stock_by_product');
  }

  @override
  Future<Result<void>> upsertInventoryStock(InventoryStockEntity stock) {
    return guard<void>(() async {
      final model = InventoryStockModel.fromEntity(stock);
      await _appDatabase.insert(
        TableNames.inventoryStock,
        model.toMap(),
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
      final boundedLimit = limit <= 0 ? 200 : limit;
      final showSerialized = hasImeiFilter == null || hasImeiFilter == true;
      final allowQuantityRows = serializedStatusFilter == null ||
          serializedStatusFilter == SerializedStockStatus.inStock;
      final showQuantity =
          (hasImeiFilter == null || hasImeiFilter == false) && allowQuantityRows;
      final trimmedQuery = searchQuery?.trim() ?? '';
      final usePrefixSearch =
          trimmedQuery.isNotEmpty && _digitsOnlyPattern.hasMatch(trimmedQuery);
      final searchLike = trimmedQuery.isEmpty
          ? null
          : (usePrefixSearch ? '$trimmedQuery%' : '%$trimmedQuery%');

      final bufferedRows = <StockRowEntity>[];
      if (showSerialized) {
        final args = <Object?>[];
        final where = StringBuffer('pm.is_active = 1');
        if (searchLike != null) {
          where.write(
            ' AND (pm.name LIKE ? OR pm.brand LIKE ?'
            ' OR ss.imei1 LIKE ? OR ss.imei2 LIKE ? OR ss.serial_number LIKE ?)',
          );
          args
            ..add(searchLike)
            ..add(searchLike)
            ..add(searchLike)
            ..add(searchLike)
            ..add(searchLike);
        }
        if (serializedStatusFilter != null) {
          where.write(' AND ss.stock_status = ?');
          args.add(serializedStatusFilter.value);
        }
        final rows = await QueryDiagnostics.trace(
          label: 'inventory.get_stock_rows.serialized',
          action: () => _appDatabase.database.rawQuery(
            '''
SELECT
  'serialized' AS row_type,
  pm.id AS product_model_id,
  pm.name,
  pm.brand,
  pm.category,
  ss.id AS serialized_stock_id,
  ss.imei1,
  ss.imei2,
  ss.serial_number,
  ss.stock_status,
  ss.condition,
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
WHERE ${where.toString()}
ORDER BY pm.name COLLATE NOCASE ASC, ss.created_at DESC
LIMIT ?
''',
            <Object?>[...args, boundedLimit],
          ),
        );
        bufferedRows.addAll(rows.map(_rowToStockRowEntity));
      }

      if (showQuantity) {
        final args = <Object?>[];
        final where = StringBuffer('pm.is_active = 1');
        if (searchLike != null) {
          where.write(' AND (pm.name LIKE ? OR pm.brand LIKE ?)');
          args
            ..add(searchLike)
            ..add(searchLike);
        }
        final rows = await QueryDiagnostics.trace(
          label: 'inventory.get_stock_rows.quantity',
          action: () => _appDatabase.database.rawQuery(
            '''
SELECT
  'quantity' AS row_type,
  pm.id AS product_model_id,
  pm.name,
  pm.brand,
  pm.category,
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
WHERE ${where.toString()}
ORDER BY pm.name COLLATE NOCASE ASC
LIMIT ?
''',
            <Object?>[...args, boundedLimit],
          ),
        );
        bufferedRows.addAll(rows.map(_rowToStockRowEntity));
      }

      if (bufferedRows.isEmpty) {
        return const <StockRowEntity>[];
      }

      bufferedRows.sort(_stockRowComparator);
      return bufferedRows.take(boundedLimit).toList(growable: false);
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
        serializedStockId: row['serialized_stock_id'] as String?,
        imei1: row['imei1'] as String?,
        imei2: row['imei2'] as String?,
        serialNumber: row['serial_number'] as String?,
        serializedStatus: row['stock_status'] != null
            ? SerializedStockStatus.fromValue(row['stock_status'] as String)
            : null,
        condition: SerializedStockCondition.fromValue(row['condition'] as String?),
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
      inventoryStockId: row['inventory_stock_id'] as String?,
      quantity: (row['quantity'] as num?)?.toInt(),
      minQuantity: (row['min_quantity'] as num?)?.toInt(),
      unitCost: (row['unit_cost'] as num?)?.toDouble(),
      unitPrice: (row['unit_price'] as num?)?.toDouble(),
      location: row['location'] as String?,
    );
  }

  int _stockRowComparator(StockRowEntity a, StockRowEntity b) {
    final aName = a.productName.toLowerCase();
    final bName = b.productName.toLowerCase();
    final byName = aName.compareTo(bName);
    if (byName != 0) {
      return byName;
    }
    if (a.type != b.type) {
      return a.type == StockRowType.serialized ? -1 : 1;
    }
    if (a.type == StockRowType.serialized) {
      return (a.imei1 ?? '').compareTo(b.imei1 ?? '');
    }
    return (a.inventoryStockId ?? '').compareTo(b.inventoryStockId ?? '');
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
