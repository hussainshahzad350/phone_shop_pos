import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/imei_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/modules/inventory/data/models/product_model.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/purchase_item_model.dart';
import 'package:phone_shop_pos/modules/purchases/data/models/purchase_model.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_status.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';

class SqlitePurchaseRepository
    with BaseRepositoryGuard
    implements PurchaseRepository {
  SqlitePurchaseRepository({required AppDatabase appDatabase})
      : this.withLedger(appDatabase: appDatabase, ledgerPostingService: null);

  SqlitePurchaseRepository.withLedger({
    required AppDatabase appDatabase,
    required LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;

  @override
  Future<Result<List<SupplierOptionEntity>>> searchSuppliers(
    String query, {
    int limit = 20,
  }) {
    return guard<List<SupplierOptionEntity>>(() async {
      final trimmedQuery = query.trim();
      final args = <Object?>[];
      final whereBuffer = StringBuffer('is_active = 1');

      if (trimmedQuery.isNotEmpty) {
        whereBuffer.write(' AND (name LIKE ? OR phone LIKE ?)');
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
          where: whereBuffer.toString(),
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
          ' AND (name LIKE ? OR barcode LIKE ? OR brand LIKE ?)',
        );
        final prefixQuery = '$trimmedQuery%';
        final likeQuery = '%$trimmedQuery%';
        args
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
  Future<Result<String>> peekNextInvoiceNumber() {
    return guard<String>(() async {
      final dateDigits = _invoiceDateDigits(DateTimeHelpers.nowUtc());
      final dateKey = 'PUR-$dateDigits';
      await _appDatabase.database.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.invoiceSequences} (
          date_key TEXT PRIMARY KEY NOT NULL,
          last_seq INTEGER NOT NULL DEFAULT 0
        );
      ''');
      final rows = await _appDatabase.database.rawQuery(
        'SELECT last_seq FROM ${TableNames.invoiceSequences} WHERE date_key = ?',
        <Object?>[dateKey],
      );
      final lastSeq =
          rows.isEmpty ? 0 : (rows.first['last_seq'] as num?)?.toInt() ?? 0;
      return 'PUR-$dateDigits-${(lastSeq + 1).toString().padLeft(4, '0')}';
    }, operation: 'peek_purchase_invoice');
  }

  String _invoiceDateDigits(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<Result<bool>> isImeiUnique(String imei) {
    return guard<bool>(() async {
      final trimmedImei = ImeiHelpers.normalize(imei);
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
    String? paymentMethod,
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
          final i1 = ImeiHelpers.normalize(entry.imei1);
          final i2 = ImeiHelpers.normalizeNullable(entry.imei2);
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
        paymentMethod: PaymentMethod.normalizeNullable(paymentMethod),
        status: PurchaseStatus.posted,
        createdAt: now,
        updatedAt: now,
      );

      int serializedCount = 0;
      int quantityCount = 0;
      late String resolvedInvoiceNumber;

      await _appDatabase.runInTransaction<void>((transaction) async {
        // Resolve the invoice number: honor a user-supplied value, otherwise
        // generate a systematic PUR-YYYYMMDD-#### number atomically via the
        // invoice_sequences table (mirrors the sales invoice strategy).
        final userInvoice = invoiceNumber?.trim();
        if (userInvoice != null && userInvoice.isNotEmpty) {
          resolvedInvoiceNumber = userInvoice;
        } else {
          await transaction.execute('''
            CREATE TABLE IF NOT EXISTS ${TableNames.invoiceSequences} (
              date_key TEXT PRIMARY KEY NOT NULL,
              last_seq INTEGER NOT NULL DEFAULT 0
            );
          ''');
          final dateDigits = _invoiceDateDigits(now);
          final dateKey = 'PUR-$dateDigits';
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
            'SELECT last_seq FROM ${TableNames.invoiceSequences} '
            'WHERE date_key = ?',
            <Object?>[dateKey],
          );
          if (seqRows.isEmpty) {
            throw StateError('Purchase invoice number could not be generated.');
          }
          final seq = (seqRows.first['last_seq'] as num).toInt();
          resolvedInvoiceNumber =
              'PUR-$dateDigits-${seq.toString().padLeft(4, '0')}';
        }

        final purchaseMap = purchaseModel.toMap();
        purchaseMap['invoice_number'] = resolvedInvoiceNumber;
        await transaction.insert(TableNames.purchases, purchaseMap);
        if (_ledgerPostingService != null &&
            supplierId != null &&
            supplierId.trim().isNotEmpty) {
          final ledgerResult = await _ledgerPostingService.postPurchaseCreated(
            purchaseId: purchaseId,
            supplierId: supplierId.trim(),
            amount: total,
            createdAt: now,
            note: notes,
            executor: transaction,
          );
          if (ledgerResult.isFailure) {
            throw StateError(ledgerResult.asFailure!.error.message);
          }
          if (sanitizedPaid > 0) {
            final normalizedPm = PaymentMethod.normalizeNullable(paymentMethod)
                ?? PaymentMethod.cash;
            final paymentLedger =
                await _ledgerPostingService.postSupplierPayment(
              transactionId: purchaseId,
              supplierId: supplierId.trim(),
              amount: sanitizedPaid,
              paymentMethod: normalizedPm,
              createdAt: now,
              note: 'Initial paid amount',
              executor: transaction,
            );
            if (paymentLedger.isFailure) {
              throw StateError(paymentLedger.asFailure!.error.message);
            }
          }
        }
        final transactionBatchImeis = <String>{};

        for (final item in items) {
          if (item.hasImei) {
            for (final entry in item.imeiEntries) {
              final normalizedImei1 = ImeiHelpers.normalize(entry.imei1);
              final normalizedImei2 =
                  ImeiHelpers.normalizeNullable(entry.imei2);
              final rawSerial = entry.serialNumber?.trim();
              final normalizedSerial =
                  (rawSerial == null || rawSerial.isEmpty) ? null : rawSerial;
              if (normalizedImei1.isEmpty ||
                  !FieldValidators.isValidImei(normalizedImei1)) {
                throw StateError(
                  '${item.productName} contains an invalid IMEI format.',
                );
              }
              if (normalizedImei2 != null) {
                if (!FieldValidators.isValidImei(normalizedImei2)) {
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
                'purchase_date': DateTimeHelpers.toSql(now),
                'condition': entry.condition.value,
                'seller_name': _normalizeOptional(entry.sellerName),
                'seller_id_card': _normalizeOptional(entry.sellerIdCard),
                'seller_address': _normalizeOptional(entry.sellerAddress),
                'seller_phone': _normalizeOptional(entry.sellerPhone),
                'remaining_warranty':
                    _normalizeOptional(entry.remainingWarranty),
                'accessories': _normalizeOptional(entry.accessories),
                'phone_condition_notes':
                    _normalizeOptional(entry.phoneConditionNotes),
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
                    : ((oldQty * oldCost) + (newQty * item.unitCost)) /
                        totalQty;

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
        invoiceNumber: resolvedInvoiceNumber,
        total: total,
        serializedItemCount: serializedCount,
        quantityItemCount: quantityCount,
      );
    }, operation: 'create_purchase_transaction');
  }

  @override
  Future<Result<PurchaseEntity>> getPurchaseById(String purchaseId) {
    return guard<PurchaseEntity>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.purchases,
        where: 'id = ?',
        whereArgs: <Object?>[purchaseId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Purchase not found: $purchaseId');
      }
      return PurchaseModel.fromMap(rows.first).toEntity();
    }, operation: 'get_purchase_by_id');
  }

  @override
  Future<Result<void>> voidPurchase({
    required String purchaseId,
    required String voidReason,
    String? voidedBy,
  }) {
    return guard<void>(() async {
      final trimmedReason = voidReason.trim();
      if (trimmedReason.isEmpty) {
        throw StateError('Void reason is required.');
      }

      // Pre-flight: block void if purchase_returns exist
      final returnRows = await _appDatabase.queryTable(
        TableNames.purchaseReturns,
        where: 'purchase_id = ?',
        whereArgs: <Object?>[purchaseId],
        limit: 1,
      );
      if (returnRows.isNotEmpty) {
        throw StateError('Cannot void a purchase that has return records.');
      }

      // Pre-flight: check serialized items are still in_stock
      final itemRows = await _appDatabase.database.query(
        TableNames.purchaseItems,
        where: 'purchase_id = ?',
        whereArgs: <Object?>[purchaseId],
      );
      for (final item in itemRows) {
        final serializedStockId = item['serialized_stock_id'] as String?;
        if (serializedStockId != null) {
          final stockRows = await _appDatabase.database.query(
            TableNames.serializedStock,
            columns: <String>['stock_status'],
            where: 'id = ?',
            whereArgs: <Object?>[serializedStockId],
            limit: 1,
          );
          if (stockRows.isNotEmpty) {
            final status = stockRows.first['stock_status'] as String?;
            if (status != SerializedStockStatus.inStock.value) {
              throw StateError(
                'Cannot void purchase: one or more items are no longer in stock '
                '(sold, damaged, or with dealer).',
              );
            }
          }
        }
      }

      final now = DateTimeHelpers.nowUtc();

      await _appDatabase.runInTransaction<void>((transaction) async {
        // Re-read inside transaction to prevent race conditions
        final purchaseRows = await transaction.query(
          TableNames.purchases,
          where: 'id = ?',
          whereArgs: <Object?>[purchaseId],
          limit: 1,
        );
        if (purchaseRows.isEmpty) {
          throw StateError('Purchase not found: $purchaseId');
        }
        final purchaseRow = purchaseRows.first;
        final currentStatus = purchaseRow['status'] as String?;
        if (currentStatus == PurchaseStatus.void_.value) {
          throw StateError('Purchase is already voided.');
        }
        final supplierId = purchaseRow['supplier_id'] as String?;

        // Mark purchase as voided
        await transaction.update(
          TableNames.purchases,
          <String, Object?>{
            'status': PurchaseStatus.void_.value,
            'voided_at': DateTimeHelpers.toSql(now),
            'voided_by': voidedBy,
            'void_reason': trimmedReason,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[purchaseId],
        );

        // Reverse inventory for each line item
        for (final item in itemRows) {
          final serializedStockId = item['serialized_stock_id'] as String?;
          if (serializedStockId != null) {
            // Remove serialized stock — purchase never happened
            await transaction.delete(
              TableNames.serializedStock,
              where: 'id = ? AND stock_status = ?',
              whereArgs: <Object?>[
                serializedStockId,
                SerializedStockStatus.inStock.value,
              ],
            );
          } else {
            // Reverse quantity and WAC
            final productModelId = item['product_model_id'] as String;
            final purchasedQty = (item['quantity'] as num).toInt();
            final purchasedCost = (item['unit_cost'] as num).toDouble();

            final stockRows = await transaction.query(
              TableNames.inventoryStock,
              columns: <String>['quantity', 'unit_cost'],
              where: 'product_model_id = ?',
              whereArgs: <Object?>[productModelId],
              limit: 1,
            );
            if (stockRows.isNotEmpty) {
              final oldQty =
                  (stockRows.first['quantity'] as num?)?.toInt() ?? 0;
              final oldCost =
                  (stockRows.first['unit_cost'] as num?)?.toDouble() ?? 0;
              final newQty = oldQty - purchasedQty < 0 ? 0 : oldQty - purchasedQty;
              final newCost = newQty > 0
                  ? ((oldQty * oldCost) - (purchasedQty * purchasedCost)) /
                      newQty
                  : oldCost;

              await transaction.update(
                TableNames.inventoryStock,
                <String, Object?>{
                  'quantity': newQty,
                  'unit_cost': newCost < 0 ? 0.0 : newCost,
                  'updated_at': DateTimeHelpers.toSql(now),
                },
                where: 'product_model_id = ?',
                whereArgs: <Object?>[productModelId],
              );
            }
          }
        }

        // Reverse ledger entry for known supplier
        if (_ledgerPostingService != null &&
            supplierId != null &&
            supplierId.trim().isNotEmpty) {
          final ledgerResult = await _ledgerPostingService.postPurchaseVoided(
            purchaseId: purchaseId,
            supplierId: supplierId.trim(),
            voidedAt: now,
            voidedBy: voidedBy,
            note: 'Void: $trimmedReason',
            executor: transaction,
          );
          if (ledgerResult.isFailure) {
            throw ledgerResult.asFailure!.error;
          }
        }

        // Audit log
        await transaction.insert(
          TableNames.auditLogs,
          <String, Object?>{
            'id': IdHelpers.newId(prefix: 'aud'),
            'action': 'void_purchase',
            'actor_id': voidedBy,
            'entity_id': purchaseId,
            'details': 'Purchase voided. Reason: $trimmedReason',
            'created_at': DateTimeHelpers.toSql(now),
          },
        );
      });
    }, operation: 'void_purchase');
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
          final normalizedImei1 = ImeiHelpers.normalize(entry.imei1);
          final normalizedImei2 = ImeiHelpers.normalizeNullable(entry.imei2);

          if (normalizedImei1.isEmpty) {
            throw StateError('${item.productName} contains an empty IMEI.');
          }
          if (!FieldValidators.isValidImei(normalizedImei1)) {
            throw StateError(
              '${item.productName} contains an invalid IMEI format.',
            );
          }
          if (entry.costPrice < 0) {
            throw StateError(
                '${item.productName} contains a negative IMEI cost.');
          }
          if (normalizedImei2 != null && normalizedImei2.isNotEmpty) {
            if (!FieldValidators.isValidImei(normalizedImei2)) {
              throw StateError(
                '${item.productName} contains an invalid IMEI format.',
              );
            }
            if (normalizedImei1 == normalizedImei2) {
              throw StateError(
                  '${item.productName} has duplicate IMEI values.');
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
