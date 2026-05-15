import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/product_model.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/serialized_stock_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/data/models/sale_item_model.dart';
import 'package:phone_shop_pos/modules/sales/data/models/sale_model.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';

class SqliteSalesRepository with BaseRepositoryGuard implements SalesRepository {
  SqliteSalesRepository({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) {
    return guard<List<ProductEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[];
      final whereBuffer = StringBuffer('is_active = 1');

      if (trimmedQuery.isNotEmpty) {
        whereBuffer.write(
          ' AND (name LIKE ? OR sku LIKE ? OR brand LIKE ? OR category LIKE ?)',
        );
        final likeQuery = '%$trimmedQuery%';
        args
          ..add(likeQuery)
          ..add(likeQuery)
          ..add(likeQuery)
          ..add(likeQuery);
      }

      final rows = await _appDatabase.queryTable(
        TableNames.productModels,
        where: whereBuffer.toString(),
        whereArgs: args,
        orderBy: 'name COLLATE NOCASE ASC',
        limit: limit,
      );

      return rows
          .map(ProductModel.fromMap)
          .map((model) => model.toEntity())
          .toList(growable: false);
    }, operation: 'search_sellable_products');
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) {
    return guard<List<CustomerOptionEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[];
      String? where;

      if (trimmedQuery.isNotEmpty) {
        where = 'name LIKE ? OR phone LIKE ?';
        final likeQuery = '%$trimmedQuery%';
        args
          ..add(likeQuery)
          ..add(likeQuery);
      }

      final rows = await _appDatabase.queryTable(
        TableNames.customers,
        where: where,
        whereArgs: args,
        orderBy: 'name COLLATE NOCASE ASC',
        limit: limit,
      );

      return rows
          .map(
            (row) => CustomerOptionEntity(
              id: row['id'] as String,
              name: row['name'] as String,
              phone: row['phone'] as String?,
            ),
          )
          .toList(growable: false);
    }, operation: 'search_customers');
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) {
    return guard<List<SerializedStockEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[productModelId, SerializedStockStatus.inStock.value];
      final whereBuffer = StringBuffer('product_model_id = ? AND stock_status = ?');

      if (trimmedQuery.isNotEmpty) {
        whereBuffer.write(
          ' AND (imei1 LIKE ? OR imei2 LIKE ? OR serial_number LIKE ?)',
        );
        final likeQuery = '%$trimmedQuery%';
        args
          ..add(likeQuery)
          ..add(likeQuery)
          ..add(likeQuery);
      }

      final rows = await _appDatabase.queryTable(
        TableNames.serializedStock,
        where: whereBuffer.toString(),
        whereArgs: args,
        orderBy: 'created_at ASC',
        limit: limit,
      );

      return rows
          .map(SerializedStockModel.fromMap)
          .map((model) => model.toEntity())
          .toList(growable: false);
    }, operation: 'get_available_imeis');
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) {
    return guard<int>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.inventoryStock,
        where: 'product_model_id = ?',
        whereArgs: <Object?>[productModelId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return 0;
      }
      return rows.first['quantity'] as int;
    }, operation: 'get_available_quantity');
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) {
    return guard<bool>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.serializedStock,
        where: 'id = ? AND stock_status = ?',
        whereArgs: <Object?>[
          serializedStockId,
          SerializedStockStatus.inStock.value,
        ],
        limit: 1,
      );
      return rows.isNotEmpty;
    }, operation: 'is_imei_available');
  }

  @override
  Future<Result<int>> getSalesCountForDate(DateTime date) {
    return guard<int>(() async {
      final start = DateTime.utc(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM ${TableNames.sales}
        WHERE sale_date >= ? AND sale_date < ?
        ''',
        <Object?>[DateTimeHelpers.toSql(start), DateTimeHelpers.toSql(end)],
      );
      if (rows.isEmpty) {
        return 0;
      }
      return (rows.first['count'] as num?)?.toInt() ?? 0;
    }, operation: 'get_sales_count_for_date');
  }

  @override
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required String invoiceNumber,
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) {
    return guard<SaleCompletionEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final saleId = IdHelpers.newId(prefix: 'sal');
      final saleModel = SaleModel(
        id: saleId,
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        userId: userId,
        saleDate: saleDate,
        subtotal: totals.subtotal,
        discount: totals.discount,
        tax: totals.tax,
        total: totals.total,
        paidAmount: totals.paidAmount,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _appDatabase.runInTransaction<void>((transaction) async {
        await transaction.insert(TableNames.sales, saleModel.toMap());

        for (final item in items) {
          if (item.serializedStockId != null) {
            final imeiRows = await transaction.query(
              TableNames.serializedStock,
              where: 'id = ? AND stock_status = ?',
              whereArgs: <Object?>[
                item.serializedStockId,
                SerializedStockStatus.inStock.value,
              ],
              limit: 1,
            );
            if (imeiRows.isEmpty) {
              throw StateError('IMEI already sold or unavailable.');
            }
            await transaction.update(
              TableNames.serializedStock,
              <String, Object?>{
                'stock_status': SerializedStockStatus.sold.value,
                'updated_at': DateTimeHelpers.toSql(now),
              },
              where: 'id = ?',
              whereArgs: <Object?>[item.serializedStockId],
            );
          } else {
            final stockRows = await transaction.query(
              TableNames.inventoryStock,
              where: 'product_model_id = ?',
              whereArgs: <Object?>[item.productModelId],
              limit: 1,
            );
            final available =
                stockRows.isEmpty ? 0 : (stockRows.first['quantity'] as int);
            if (available < item.quantity) {
              throw StateError('Insufficient quantity for ${item.productName}.');
            }

            await transaction.update(
              TableNames.inventoryStock,
              <String, Object?>{
                'quantity': available - item.quantity,
                'updated_at': DateTimeHelpers.toSql(now),
              },
              where: 'product_model_id = ?',
              whereArgs: <Object?>[item.productModelId],
            );
          }

          final saleItemModel = SaleItemModel(
            id: IdHelpers.newId(prefix: 'sli'),
            saleId: saleId,
            productModelId: item.productModelId,
            serializedStockId: item.serializedStockId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discount: 0,
            lineTotal: item.lineTotal,
            createdAt: now,
            updatedAt: now,
          );
          await transaction.insert(TableNames.saleItems, saleItemModel.toMap());
        }
      });

      return SaleCompletionEntity(
        saleId: saleId,
        invoiceNumber: invoiceNumber,
        totals: totals,
      );
    }, operation: 'create_sale_transaction');
  }
}
