import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/product_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/purchase_item_model.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/purchase_model.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';

class SqlitePurchaseRepository
    with BaseRepositoryGuard
    implements PurchaseRepository {
  SqlitePurchaseRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static final RegExp _imeiPattern = RegExp(r'^\d{14,15}$');

  final AppDatabase _appDatabase;

  @override
  Future<Result<List<SupplierOptionEntity>>> searchSuppliers(
    String query, {
    int limit = 20,
  }) {
    return guard<List<SupplierOptionEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[];
      String? where;

      if (trimmedQuery.isNotEmpty) {
        where = 'name LIKE ? OR phone LIKE ?';
        final phonePrefix = '$trimmedQuery%';
        final likeQuery = '%$trimmedQuery%';
        args
          ..add(likeQuery)
          ..add(phonePrefix);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'purchases.search_suppliers',
        action: () => _appDatabase.queryTable(
          TableNames.suppliers,
          where: where,
          whereArgs: args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
      );

      return rows
          .map(
            (row) => SupplierOptionEntity(
              id: row['id'] as String,
              name: row['name'] as String,
              phone: row['phone'] as String?,
              contactPerson: row['contact_person'] as String?,
            ),
          )
          .toList(growable: false);
    }, operation: 'search_suppliers');
  }

  @override
  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    int limit = 20,
  }) {
    return guard<List<ProductEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[];
      final whereBuffer = StringBuffer('is_active = 1');

      if (trimmedQuery.isNotEmpty) {
        whereBuffer.write(
          ' AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ? OR brand LIKE ?)',
        );
        final prefixQuery = '$trimmedQuery%';
        final likeQuery = '%$trimmedQuery%';
        args
          ..add(prefixQuery)
          ..add(prefixQuery)
          ..add(prefixQuery)
          ..add(likeQuery);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'purchases.search_products',
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
    }, operation: 'search_products');
  }

  @override
  Future<Result<bool>> isImeiUnique(String imei) {
    return guard<bool>(() async {
      final trimmedImei = imei.trim();
      final rows = await _appDatabase.queryTable(
        TableNames.serializedStock,
        where: 'imei1 = ? OR imei2 = ?',
        whereArgs: <Object?>[trimmedImei, trimmedImei],
        limit: 1,
      );
      return rows.isEmpty;
    }, operation: 'is_imei_unique');
  }

  @override
  Future<Result<PurchaseCompletionEntity>> createPurchaseTransaction({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
    required double paidAmount,
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  }) {
    return guard<PurchaseCompletionEntity>(() async {
      _validatePurchaseItems(items);

      final now = DateTimeHelpers.nowUtc();
      final purchaseId = IdHelpers.newId(prefix: 'pur');

      // ── Phase 2: IMEI pre-transaction uniqueness validation ───────────────
      // Collect and normalize all IMEI values across all items in the batch.
      final allImeiValues = <String>[];
      for (final item in items) {
        if (!item.hasImei) continue;
        for (final entry in item.imeiEntries) {
          final i1 = entry.imei1.trim();
          final i2 = entry.imei2?.trim();
          if (i1.isNotEmpty) allImeiValues.add(i1);
          if (i2 != null && i2.isNotEmpty) allImeiValues.add(i2);
        }
      }

      // Check for duplicates within this batch itself.
      final seen = <String>{};
      for (final imei in allImeiValues) {
        if (!seen.add(imei)) {
          throw StateError('Duplicate IMEI in batch: $imei');
        }
      }

      // Check each IMEI against the database before starting the transaction.
      for (final imei in allImeiValues) {
        final rows = await _appDatabase.queryTable(
          TableNames.serializedStock,
          where: 'imei1 = ? OR imei2 = ?',
          whereArgs: <Object?>[imei, imei],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          throw StateError('IMEI already exists in stock: $imei');
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      final subtotal =
          items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final sanitizedDiscount = discount.clamp(0, subtotal).toDouble();
      final sanitizedTax = tax < 0 ? 0.0 : tax;
      final total = (subtotal - sanitizedDiscount) + sanitizedTax;
      final sanitizedPaid = paidAmount < 0 ? 0.0 : paidAmount;

      final purchaseModel = PurchaseModel(
        id: purchaseId,
        supplierId: supplierId,
        invoiceNumber: invoiceNumber,
        purchaseDate: now,
        subtotal: subtotal,
        discount: sanitizedDiscount,
        tax: sanitizedTax,
        total: total,
        paidAmount: sanitizedPaid,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      int serializedCount = 0;
      int quantityCount = 0;

      await _appDatabase.runInTransaction<void>((transaction) async {
        await transaction.insert(TableNames.purchases, purchaseModel.toMap());
        final transactionBatchImeis = <String>{};

        for (final item in items) {
          if (item.hasImei) {
            for (final entry in item.imeiEntries) {
              final normalizedImei1 = entry.imei1.trim();
              final rawImei2 = entry.imei2?.trim();
              final normalizedImei2 =
                  (rawImei2 == null || rawImei2.isEmpty) ? null : rawImei2;
              final rawSerial = entry.serialNumber?.trim();
              final normalizedSerial =
                  (rawSerial == null || rawSerial.isEmpty) ? null : rawSerial;
              if (normalizedImei1.isEmpty ||
                  !_imeiPattern.hasMatch(normalizedImei1)) {
                throw StateError(
                  '${item.productName} contains an invalid IMEI format.',
                );
              }
              if (normalizedImei2 != null) {
                if (!_imeiPattern.hasMatch(normalizedImei2)) {
                  throw StateError(
                    '${item.productName} contains an invalid IMEI format.',
                  );
                }
                if (normalizedImei1 == normalizedImei2) {
                  throw StateError(
                    '${item.productName} has duplicate IMEI values.',
                  );
                }
              }

              final imeiValues = <String>[
                normalizedImei1,
                if (normalizedImei2 != null) normalizedImei2,
              ];
              for (final imei in imeiValues) {
                if (!transactionBatchImeis.add(imei)) {
                  throw StateError('Duplicate IMEI in batch: $imei');
                }
                final existingRows = await transaction.query(
                  TableNames.serializedStock,
                  columns: const <String>['id'],
                  where: 'imei1 = ? OR imei2 = ?',
                  whereArgs: <Object?>[imei, imei],
                  limit: 1,
                );
                if (existingRows.isNotEmpty) {
                  throw StateError('IMEI already exists in stock: $imei');
                }
              }

              final stockId = IdHelpers.newId(prefix: 'ser');
              await transaction
                  .insert(TableNames.serializedStock, <String, Object?>{
                'id': stockId,
                'product_model_id': item.productModelId,
                'imei1': normalizedImei1,
                'imei2': normalizedImei2,
                'serial_number': normalizedSerial,
                'cost_price': entry.costPrice,
                'selling_price': entry.sellingPrice,
                'stock_status': SerializedStockStatus.inStock.value,
                'supplier_id': item.supplierId ?? supplierId,
                'notes': null,
                'condition': entry.condition.value,
                'seller_name': _normalizeOptional(entry.sellerName),
                'seller_id_card': _normalizeOptional(entry.sellerIdCard),
                'seller_address': _normalizeOptional(entry.sellerAddress),
                'seller_phone': _normalizeOptional(entry.sellerPhone),
                'remaining_warranty': _normalizeOptional(entry.remainingWarranty),
                'accessories': _normalizeOptional(entry.accessories),
                'phone_condition_notes': _normalizeOptional(entry.phoneConditionNotes),
                'created_at': DateTimeHelpers.toSql(now),
                'updated_at': DateTimeHelpers.toSql(now),
              });

              final itemModel = PurchaseItemModel(
                id: IdHelpers.newId(prefix: 'pri'),
                purchaseId: purchaseId,
                productModelId: item.productModelId,
                serializedStockId: stockId,
                quantity: 1,
                unitCost: entry.costPrice,
                lineTotal: entry.costPrice,
                createdAt: now,
                updatedAt: now,
              );
              await transaction.insert(
                  TableNames.purchaseItems, itemModel.toMap());
              serializedCount++;
            }
          } else {
            await transaction.rawInsert(
              '''
              INSERT OR IGNORE INTO ${TableNames.inventoryStock}
                (id, product_model_id, quantity, min_quantity, unit_cost, unit_price, created_at, updated_at)
              VALUES (?, ?, 0, 0, ?, 0, ?, ?)
              ''',
              <Object?>[
                IdHelpers.newId(prefix: 'stk'),
                item.productModelId,
                item.unitCost,
                DateTimeHelpers.toSql(now),
                DateTimeHelpers.toSql(now),
              ],
            );

            final stockRows = await transaction.query(
              TableNames.inventoryStock,
              columns: <String>['quantity', 'unit_cost'],
              where: 'product_model_id = ?',
              whereArgs: <Object?>[item.productModelId],
              limit: 1,
            );
            if (stockRows.isEmpty) {
              throw StateError(
                'Inventory stock row missing after upsert for ${item.productName}.',
              );
            }

            final oldQty = (stockRows.first['quantity'] as num?)?.toInt() ?? 0;
            final oldCost =
                (stockRows.first['unit_cost'] as num?)?.toDouble() ?? 0;
            final newQty = item.quantity;
            final totalQty = oldQty + newQty;
            final averageCost = totalQty <= 0
                ? oldCost
                : oldQty <= 0
                    ? item.unitCost
                    : ((oldQty * oldCost) + (newQty * item.unitCost)) / totalQty;

            await transaction.update(
              TableNames.inventoryStock,
              <String, Object?>{
                'quantity': totalQty,
                'unit_cost': averageCost,
                'updated_at': DateTimeHelpers.toSql(now),
              },
              where: 'product_model_id = ?',
              whereArgs: <Object?>[item.productModelId],
            );

            final itemModel = PurchaseItemModel(
              id: IdHelpers.newId(prefix: 'pri'),
              purchaseId: purchaseId,
              productModelId: item.productModelId,
              serializedStockId: null,
              quantity: item.quantity,
              unitCost: item.unitCost,
              lineTotal: item.lineTotal,
              createdAt: now,
              updatedAt: now,
            );
            await transaction.insert(
                TableNames.purchaseItems, itemModel.toMap());
            quantityCount++;
          }
        }
      });

      return PurchaseCompletionEntity(
        purchaseId: purchaseId,
        invoiceNumber: invoiceNumber,
        total: total,
        serializedItemCount: serializedCount,
        quantityItemCount: quantityCount,
      );
    }, operation: 'create_purchase_transaction');
  }

  void _validatePurchaseItems(List<PurchaseFormItem> items) {
    if (items.isEmpty) {
      throw StateError('Purchase requires at least one item.');
    }

    for (final item in items) {
      if (item.hasImei) {
        if (item.imeiEntries.isEmpty) {
          throw StateError(
              '${item.productName} requires at least one IMEI entry.');
        }

        for (final entry in item.imeiEntries) {
          final normalizedImei1 = entry.imei1.trim();
          final normalizedImei2 = entry.imei2?.trim();

          if (normalizedImei1.isEmpty) {
            throw StateError('${item.productName} contains an empty IMEI.');
          }
          if (!_imeiPattern.hasMatch(normalizedImei1)) {
            throw StateError(
              '${item.productName} contains an invalid IMEI format.',
            );
          }
          if (entry.costPrice < 0) {
            throw StateError(
                '${item.productName} contains a negative IMEI cost.');
          }
          if (normalizedImei2 != null &&
              normalizedImei2.isNotEmpty) {
            if (!_imeiPattern.hasMatch(normalizedImei2)) {
              throw StateError(
                '${item.productName} contains an invalid IMEI format.',
              );
            }
            if (normalizedImei1 == normalizedImei2) {
              throw StateError('${item.productName} has duplicate IMEI values.');
            }
          }
        }
        continue;
      }

      if (item.quantity <= 0) {
        throw StateError('${item.productName} has invalid quantity.');
      }
      if (item.unitCost < 0) {
        throw StateError('${item.productName} has invalid unit cost.');
      }
      if (item.imeiEntries.isNotEmpty) {
        throw StateError(
            '${item.productName} cannot mix quantity and IMEI stock.');
      }
    }
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
