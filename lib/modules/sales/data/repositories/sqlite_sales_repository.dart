import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteSalesRepository with BaseRepositoryGuard implements SalesRepository {
  SqliteSalesRepository({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  static final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');

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
          ' AND (sku LIKE ? OR name LIKE ? OR brand LIKE ? OR category LIKE ?)',
        );
        final prefixQuery = '$trimmedQuery%';
        final containsQuery = '%$trimmedQuery%';
        args
          ..add(prefixQuery)
          ..add(containsQuery)
          ..add(containsQuery)
          ..add(containsQuery);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'sales.search_sellable_products',
        action: () => _appDatabase.queryTable(
          TableNames.productModels,
          where: whereBuffer.toString(),
          whereArgs: args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
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
        where = 'phone LIKE ? OR name LIKE ?';
        final prefixQuery = '$trimmedQuery%';
        final containsQuery = '%$trimmedQuery%';
        args
          ..add(prefixQuery)
          ..add(containsQuery);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'sales.search_customers',
        action: () => _appDatabase.queryTable(
          TableNames.customers,
          where: where,
          whereArgs: args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
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
        final prefixQuery = '$trimmedQuery%';
        if (_digitsOnlyPattern.hasMatch(trimmedQuery)) {
          whereBuffer.write(
            ' AND (imei1 LIKE ? OR imei2 LIKE ? OR serial_number LIKE ?)',
          );
          args
            ..add(prefixQuery)
            ..add(prefixQuery)
            ..add(prefixQuery);
        } else {
          final containsQuery = '%$trimmedQuery%';
          whereBuffer.write(
            ' AND (imei1 LIKE ? OR imei2 LIKE ? OR serial_number LIKE ?)',
          );
          args
            ..add(containsQuery)
            ..add(containsQuery)
            ..add(containsQuery);
        }
      }

      final rows = await QueryDiagnostics.trace(
        label: 'sales.get_available_imeis',
        action: () => _appDatabase.queryTable(
          TableNames.serializedStock,
          where: whereBuffer.toString(),
          whereArgs: args,
          orderBy: 'created_at ASC',
          limit: limit,
        ),
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
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) {
    return guard<SaleCompletionEntity>(() async {
      _validateSaleRequest(items: items, totals: totals);

      final now = DateTimeHelpers.nowUtc();
      final saleId = IdHelpers.newId(prefix: 'sal');

      // Invoice number is generated atomically inside the transaction using
      // the invoice_sequences table.  This eliminates the COUNT-based race
      // condition that existed when the number was computed before the
      // transaction began.
      late String invoiceNumber;

      await _appDatabase.runInTransaction<void>((transaction) async {
        // ── Phase 4: atomic invoice sequence ─────────────────────────────
        final dateKey =
            '${saleDate.year.toString().padLeft(4, '0')}'
            '${saleDate.month.toString().padLeft(2, '0')}'
            '${saleDate.day.toString().padLeft(2, '0')}';

        await transaction.rawInsert(
          'INSERT OR IGNORE INTO ${TableNames.invoiceSequences} '
          '(date_key, last_seq) VALUES (?, 0)',
          <Object?>[dateKey],
        );
        await transaction.rawUpdate(
          'UPDATE ${TableNames.invoiceSequences} '
          'SET last_seq = last_seq + 1 WHERE date_key = ?',
          <Object?>[dateKey],
        );
        final seqRows = await transaction.rawQuery(
          'SELECT last_seq FROM ${TableNames.invoiceSequences} WHERE date_key = ?',
          <Object?>[dateKey],
        );
        final seq = (seqRows.first['last_seq'] as num).toInt();
        invoiceNumber =
            'INV-$dateKey-${seq.toString().padLeft(4, '0')}';

        // ── Sale header ───────────────────────────────────────────────────
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
        await transaction.insert(TableNames.sales, saleModel.toMap());

        // ── Line items ────────────────────────────────────────────────────
        for (final item in items) {
          double costPrice;

          if (item.serializedStockId != null) {
            // Phase 2: re-confirm availability inside the transaction.
            final imeiRows = await transaction.query(
              TableNames.serializedStock,
              columns: <String>['stock_status', 'cost_price'],
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

            // Phase 3: snapshot the serialized stock cost price at sale time.
            costPrice =
                (imeiRows.first['cost_price'] as num?)?.toDouble() ?? 0;

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
              columns: <String>['quantity', 'unit_cost'],
              where: 'product_model_id = ?',
              whereArgs: <Object?>[item.productModelId],
              limit: 1,
            );
            final available =
                stockRows.isEmpty ? 0 : (stockRows.first['quantity'] as int);
            if (available < item.quantity) {
              throw StateError(
                'Insufficient quantity for ${item.productName}.',
              );
            }

            // Phase 3: snapshot the per-unit cost from inventory at sale time.
            costPrice =
                (stockRows.isEmpty
                    ? 0
                    : (stockRows.first['unit_cost'] as num?)?.toDouble()) ??
                0;

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
            costPrice: costPrice,
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

  void _validateSaleRequest({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
  }) {
    if (items.isEmpty) {
      throw StateError('Sale requires at least one item.');
    }
    if (totals.subtotal < 0 ||
        totals.discount < 0 ||
        totals.tax < 0 ||
        totals.total < 0 ||
        totals.paidAmount < 0) {
      throw StateError('Sale totals cannot be negative.');
    }

    final serializedIds = <String>{};
    for (final item in items) {
      if (item.unitPrice < 0) {
        throw StateError('${item.productName} has invalid unit price.');
      }

      if (item.hasImei) {
        final serializedStockId = item.serializedStockId;
        if (serializedStockId == null || serializedStockId.isEmpty) {
          throw StateError('${item.productName} requires a serialized stock ID.');
        }
        if (item.quantity != 1) {
          throw StateError('${item.productName} serialized quantity must be 1.');
        }
        if (!serializedIds.add(serializedStockId)) {
          throw StateError('Duplicate serialized stock detected in sale.');
        }
        continue;
      }

      if (item.quantity <= 0) {
        throw StateError('${item.productName} has invalid quantity.');
      }
      if (item.serializedStockId != null) {
        throw StateError('${item.productName} cannot reference serialized stock.');
      }
    }
  }
}
