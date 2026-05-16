import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class OperationsWorkflowService with BaseRepositoryGuard {
  OperationsWorkflowService({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<List<SalesHistoryRowEntity>>> searchSalesHistory({
    required String invoiceQuery,
    required String customerQuery,
    required DateTime? startDate,
    required DateTime? endDate,
    bool pendingOnly = false,
    int limit = 100,
    int offset = 0,
  }) {
    return guard<List<SalesHistoryRowEntity>>(() async {
      final whereClauses = <String>['1 = 1'];
      final args = <Object?>[];

      final trimmedInvoice = invoiceQuery.trim();
      if (trimmedInvoice.isNotEmpty) {
        whereClauses.add('s.invoice_number LIKE ?');
        args.add('%$trimmedInvoice%');
      }

      final trimmedCustomer = customerQuery.trim();
      if (trimmedCustomer.isNotEmpty) {
        whereClauses.add(
          '(COALESCE(c.name, \'Walk-in Customer\') LIKE ? OR '
          'COALESCE(c.phone, \'\') LIKE ? OR COALESCE(c.id, \'\') LIKE ?)',
        );
        args
          ..add('%$trimmedCustomer%')
          ..add('%$trimmedCustomer%')
          ..add('%$trimmedCustomer%');
      }

      if (startDate != null) {
        final startUtc = DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('s.sale_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('s.sale_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      if (pendingOnly) {
        whereClauses.add('s.paid_amount < s.total');
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.operations.search_sales_history',
        action: () => _appDatabase.database.rawQuery(
          '''
          SELECT
            s.id AS sale_id,
            s.invoice_number,
            s.sale_date,
            COALESCE(c.name, 'Walk-in Customer') AS customer_name,
            c.id AS customer_id,
            s.total,
            s.paid_amount,
            s.payment_method,
            pj.id AS print_job_id
          FROM ${TableNames.sales} s
          LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
          LEFT JOIN ${TableNames.printJobs} pj ON pj.sale_id = s.id
          WHERE ${whereClauses.join(' AND ')}
          ORDER BY s.sale_date DESC
          LIMIT ? OFFSET ?
          ''',
          <Object?>[...args, limit, offset],
        ),
      );

      return rows.map((row) {
        return SalesHistoryRowEntity(
          saleId: row['sale_id'] as String,
          invoiceNumber: row['invoice_number'] as String,
          saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
          customerName: row['customer_name'] as String,
          customerId: row['customer_id'] as String?,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
          paymentMethod: PaymentMethod.normalizeNullable(row['payment_method'] as String?),
          printJobId: row['print_job_id'] as String?,
        );
      }).toList(growable: false);
    }, operation: 'search_sales_history');
  }

  Future<Result<SalesInvoiceDetailEntity?>> getSalesInvoiceDetail(
    String saleId,
  ) {
    return guard<SalesInvoiceDetailEntity?>(() async {
      final headerRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          s.id AS sale_id,
          s.invoice_number,
          s.sale_date,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          c.id AS customer_id,
          s.total,
          s.paid_amount,
          s.payment_method,
          pj.id AS print_job_id,
          s.notes
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        LEFT JOIN ${TableNames.printJobs} pj ON pj.sale_id = s.id
        WHERE s.id = ?
        LIMIT 1
        ''',
        <Object?>[saleId],
      );
      if (headerRows.isEmpty) {
        return null;
      }
      final header = headerRows.first;

      final itemRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          si.id AS sale_item_id,
          si.product_model_id,
          pm.name AS product_name,
          pm.has_imei,
          si.quantity,
          si.unit_price,
          si.line_total,
          si.serialized_stock_id,
          ss.imei1,
          COALESCE((
            SELECT SUM(sr.return_qty)
            FROM ${TableNames.saleReturns} sr
            WHERE sr.sale_item_id = si.id
          ), 0) AS returned_qty
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        LEFT JOIN ${TableNames.serializedStock} ss ON ss.id = si.serialized_stock_id
        WHERE si.sale_id = ?
        ORDER BY si.created_at ASC
        ''',
        <Object?>[saleId],
      );

      return SalesInvoiceDetailEntity(
        sale: SalesHistoryRowEntity(
          saleId: header['sale_id'] as String,
          invoiceNumber: header['invoice_number'] as String,
          saleDate: DateTimeHelpers.fromSql(header['sale_date'] as String),
          customerName: header['customer_name'] as String,
          customerId: header['customer_id'] as String?,
          total: (header['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (header['paid_amount'] as num?)?.toDouble() ?? 0,
          paymentMethod:
              PaymentMethod.normalizeNullable(header['payment_method'] as String?),
          printJobId: header['print_job_id'] as String?,
        ),
        items: itemRows.map((row) {
          return SalesInvoiceItemEntity(
            saleItemId: row['sale_item_id'] as String,
            productModelId: row['product_model_id'] as String,
            productName: row['product_name'] as String,
            hasImei: ((row['has_imei'] as num?)?.toInt() ?? 0) == 1,
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
            unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
            lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
            serializedStockId: row['serialized_stock_id'] as String?,
            imei: row['imei1'] as String?,
            returnedQty: (row['returned_qty'] as num?)?.toInt() ?? 0,
          );
        }).toList(growable: false),
        notes: header['notes'] as String?,
      );
    }, operation: 'get_sales_invoice_detail');
  }

  Future<Result<PaymentCollectionEntity>> collectPayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) {
    return guard<PaymentCollectionEntity>(() async {
      final normalizedMethod = PaymentMethod.normalizeNullable(paymentMethod);
      if (normalizedMethod == null) {
        throw StateError('Payment method must be cash, card, or bank.');
      }
      if (amount <= 0) {
        throw StateError('Payment amount must be greater than zero.');
      }
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final notesError = NotesSafety.validate(normalizedNotes, fieldLabel: 'Payment notes');
      if (notesError != null) {
        throw StateError(notesError);
      }

      late PaymentCollectionEntity summary;
      await _appDatabase.runInTransaction<void>((transaction) async {
        final saleRows = await transaction.query(
          TableNames.sales,
          columns: <String>['total', 'paid_amount'],
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
          limit: 1,
        );
        if (saleRows.isEmpty) {
          throw StateError('Sale not found.');
        }

        final total = (saleRows.first['total'] as num?)?.toDouble() ?? 0;
        final paid = (saleRows.first['paid_amount'] as num?)?.toDouble() ?? 0;
        final remaining = (total - paid).clamp(0, double.infinity);
        if (remaining <= 0) {
          throw StateError('This sale is already fully paid.');
        }
        if (amount > remaining) {
          throw StateError('Payment cannot exceed remaining balance.');
        }

        final now = DateTimeHelpers.nowUtc();
        final newPaidAmount = paid + amount;

        await transaction.insert(TableNames.salePayments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'pay'),
          'sale_id': saleId,
          'amount': amount,
          'payment_method': normalizedMethod,
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });

        await transaction.update(
          TableNames.sales,
          <String, Object?>{
            'paid_amount': newPaidAmount,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
        );

        summary = PaymentCollectionEntity(
          newPaidAmount: newPaidAmount,
          remainingBalance: (total - newPaidAmount).clamp(0, double.infinity),
        );
      });

      return summary;
    }, operation: 'collect_payment');
  }

  Future<Result<void>> processReturn({
    required String saleId,
    required SalesInvoiceItemEntity item,
    required int quantity,
    required String reason,
    String? notes,
  }) {
    return guard<void>(() async {
      final trimmedReason = reason.trim();
      if (trimmedReason.isEmpty) {
        throw StateError('Return reason is required.');
      }
      if (quantity <= 0) {
        throw StateError('Return quantity must be greater than zero.');
      }
      if (quantity > item.returnableQty) {
        throw StateError('Return quantity exceeds available returnable quantity.');
      }
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();

      await _appDatabase.runInTransaction<void>((transaction) async {
        // ── Read unit cost snapshot from sale_items ───────────────────────
        final saleItemRows = await transaction.query(
          TableNames.saleItems,
          columns: <String>['cost_price'],
          where: 'id = ?',
          whereArgs: <Object?>[item.saleItemId],
          limit: 1,
        );
        if (saleItemRows.isEmpty) {
          throw StateError('Sale item not found for return.');
        }
        final unitCostPrice =
            (saleItemRows.first['cost_price'] as num?)?.toDouble() ?? 0;

        late double returnAmount;
        String? returnedSerializedId;
        String returnType;

        if (item.hasImei) {
          if (quantity != 1) {
            throw StateError('Serialized item return must be exactly one unit.');
          }
          final serializedId = item.serializedStockId;
          if (serializedId == null || serializedId.isEmpty) {
            throw StateError('Serialized item is missing stock reference.');
          }

          final duplicate = await transaction.query(
            TableNames.saleReturns,
            where: 'sale_item_id = ? AND serialized_stock_id = ?',
            whereArgs: <Object?>[item.saleItemId, serializedId],
            limit: 1,
          );
          if (duplicate.isNotEmpty) {
            throw StateError('This IMEI is already returned.');
          }

          await transaction.update(
            TableNames.serializedStock,
            <String, Object?>{
              'stock_status': 'in_stock',
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'id = ?',
            whereArgs: <Object?>[serializedId],
          );

          returnAmount = item.lineTotal;
          returnedSerializedId = serializedId;
          returnType = 'imei';
        } else {
          await transaction.rawInsert(
            '''
            INSERT OR IGNORE INTO ${TableNames.inventoryStock}
            (id, product_model_id, quantity, min_quantity, unit_cost, unit_price, created_at, updated_at)
            VALUES (?, ?, 0, 0, 0, 0, ?, ?)
            ''',
            <Object?>[
              IdHelpers.newId(prefix: 'stk'),
              item.productModelId,
              DateTimeHelpers.toSql(now),
              DateTimeHelpers.toSql(now),
            ],
          );

          final stockRows = await transaction.query(
            TableNames.inventoryStock,
            columns: <String>['quantity'],
            where: 'product_model_id = ?',
            whereArgs: <Object?>[item.productModelId],
            limit: 1,
          );
          if (stockRows.isEmpty) {
            throw StateError('Inventory row missing for return item.');
          }
          final oldQty = (stockRows.first['quantity'] as num?)?.toInt() ?? 0;
          final newQty = oldQty + quantity;

          await transaction.update(
            TableNames.inventoryStock,
            <String, Object?>{
              'quantity': newQty,
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'product_model_id = ?',
            whereArgs: <Object?>[item.productModelId],
          );

          returnAmount = item.unitPrice * quantity;
          returnedSerializedId = null;
          returnType = 'quantity';
        }

        // ── Insert return audit record ────────────────────────────────────
        await transaction.insert(TableNames.saleReturns, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'ret'),
          'sale_id': saleId,
          'sale_item_id': item.saleItemId,
          'product_model_id': item.productModelId,
          'serialized_stock_id': returnedSerializedId,
          'return_type': returnType,
          'return_qty': quantity,
          'return_amount': returnAmount,
          'cost_price': unitCostPrice,
          'reason': trimmedReason,
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });

        // ── Refund Model: reduce sale total and clamp paid_amount ─────────
        final saleRows = await transaction.query(
          TableNames.sales,
          columns: <String>['total', 'paid_amount'],
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
          limit: 1,
        );
        if (saleRows.isEmpty) {
          throw StateError('Sale not found for financial adjustment.');
        }
        final currentTotal =
            (saleRows.first['total'] as num?)?.toDouble() ?? 0;
        final currentPaid =
            (saleRows.first['paid_amount'] as num?)?.toDouble() ?? 0;
        final newTotal =
            (currentTotal - returnAmount).clamp(0.0, currentTotal);
        final newPaid = currentPaid.clamp(0, newTotal);

        await transaction.update(
          TableNames.sales,
          <String, Object?>{
            'total': newTotal,
            'paid_amount': newPaid,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
        );
      });
    }, operation: 'process_sale_return');
  }

  Future<Result<List<PurchaseHistoryRowEntity>>> searchPurchaseHistory({
    required String supplierQuery,
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) {
    return guard<List<PurchaseHistoryRowEntity>>(() async {
      final whereClauses = <String>['1 = 1'];
      final args = <Object?>[];

      final trimmedSupplier = supplierQuery.trim();
      if (trimmedSupplier.isNotEmpty) {
        whereClauses.add(
          '(COALESCE(sp.name, \'Unknown Supplier\') LIKE ? OR '
          'COALESCE(sp.phone, \'\') LIKE ? OR COALESCE(sp.id, \'\') LIKE ?)',
        );
        args
          ..add('%$trimmedSupplier%')
          ..add('%$trimmedSupplier%')
          ..add('%$trimmedSupplier%');
      }

      if (startDate != null) {
        final startUtc = DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('p.purchase_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('p.purchase_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.operations.search_purchase_history',
        action: () => _appDatabase.database.rawQuery(
          '''
          SELECT
            p.id AS purchase_id,
            p.purchase_date,
            COALESCE(sp.name, 'Unknown Supplier') AS supplier_name,
            p.invoice_number,
            p.total,
            p.paid_amount
          FROM ${TableNames.purchases} p
          LEFT JOIN ${TableNames.suppliers} sp ON sp.id = p.supplier_id
          WHERE ${whereClauses.join(' AND ')}
          ORDER BY p.purchase_date DESC
          LIMIT ? OFFSET ?
          ''',
          <Object?>[...args, limit, offset],
        ),
      );

      return rows.map((row) {
        return PurchaseHistoryRowEntity(
          purchaseId: row['purchase_id'] as String,
          purchaseDate: DateTimeHelpers.fromSql(row['purchase_date'] as String),
          supplierName: row['supplier_name'] as String,
          invoiceNumber: row['invoice_number'] as String?,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
        );
      }).toList(growable: false);
    }, operation: 'search_purchase_history');
  }

  Future<Result<PurchaseHistoryDetailEntity?>> getPurchaseHistoryDetail(
    String purchaseId,
  ) {
    return guard<PurchaseHistoryDetailEntity?>(() async {
      final headerRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          p.id AS purchase_id,
          p.purchase_date,
          COALESCE(sp.name, 'Unknown Supplier') AS supplier_name,
          p.invoice_number,
          p.total,
          p.paid_amount,
          p.notes
        FROM ${TableNames.purchases} p
        LEFT JOIN ${TableNames.suppliers} sp ON sp.id = p.supplier_id
        WHERE p.id = ?
        LIMIT 1
        ''',
        <Object?>[purchaseId],
      );
      if (headerRows.isEmpty) {
        return null;
      }
      final header = headerRows.first;

      final itemRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          pm.name AS product_name,
          pi.quantity,
          pi.unit_cost,
          pi.line_total,
          ss.imei1
        FROM ${TableNames.purchaseItems} pi
        JOIN ${TableNames.productModels} pm ON pm.id = pi.product_model_id
        LEFT JOIN ${TableNames.serializedStock} ss ON ss.id = pi.serialized_stock_id
        WHERE pi.purchase_id = ?
        ORDER BY pi.created_at ASC
        ''',
        <Object?>[purchaseId],
      );

      return PurchaseHistoryDetailEntity(
        purchase: PurchaseHistoryRowEntity(
          purchaseId: header['purchase_id'] as String,
          purchaseDate: DateTimeHelpers.fromSql(header['purchase_date'] as String),
          supplierName: header['supplier_name'] as String,
          invoiceNumber: header['invoice_number'] as String?,
          total: (header['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (header['paid_amount'] as num?)?.toDouble() ?? 0,
        ),
        items: itemRows.map((row) {
          return PurchaseHistoryItemEntity(
            productName: row['product_name'] as String,
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
            unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
            lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
            imei: row['imei1'] as String?,
          );
        }).toList(growable: false),
        notes: header['notes'] as String?,
      );
    }, operation: 'get_purchase_history_detail');
  }

  Future<Result<List<SupplierLedgerRowEntity>>> getSupplierLedger({
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 200,
    int offset = 0,
  }) {
    return guard<List<SupplierLedgerRowEntity>>(() async {
      final whereClauses = <String>['1 = 1'];
      final args = <Object?>[];

      if (startDate != null) {
        final startUtc = DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('p.purchase_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('p.purchase_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE(sp.name, 'Unknown Supplier') AS supplier_name,
          COUNT(*) AS purchase_count,
          COALESCE(SUM(p.total), 0) AS total_purchases,
          COALESCE(SUM(p.paid_amount), 0) AS total_paid
        FROM ${TableNames.purchases} p
        LEFT JOIN ${TableNames.suppliers} sp ON sp.id = p.supplier_id
        WHERE ${whereClauses.join(' AND ')}
        GROUP BY COALESCE(p.supplier_id, 'unknown_supplier')
        ORDER BY total_purchases DESC
        LIMIT ? OFFSET ?
        ''',
        <Object?>[...args, limit, offset],
      );

      return rows.map((row) {
        return SupplierLedgerRowEntity(
          supplierName: row['supplier_name'] as String,
          purchaseCount: (row['purchase_count'] as num?)?.toInt() ?? 0,
          totalPurchases: (row['total_purchases'] as num?)?.toDouble() ?? 0,
          totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0,
        );
      }).toList(growable: false);
    }, operation: 'supplier_ledger');
  }

  Future<Result<int>> applyQuantityStockAdjustment({
    required String productModelId,
    required int delta,
    required String reason,
    String? notes,
  }) {
    return guard<int>(() async {
      if (delta == 0) {
        throw StateError('Adjustment quantity cannot be zero.');
      }
      _validateAdjustmentReason(reason);
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();
      late int newQty;

      await _appDatabase.runInTransaction<void>((transaction) async {
        final rows = await transaction.query(
          TableNames.inventoryStock,
          columns: <String>['quantity'],
          where: 'product_model_id = ?',
          whereArgs: <Object?>[productModelId],
          limit: 1,
        );

        if (rows.isEmpty) {
          if (delta < 0) {
            throw StateError('Cannot decrease stock. Item has no inventory row.');
          }
          await transaction.insert(TableNames.inventoryStock, <String, Object?>{
            'id': IdHelpers.newId(prefix: 'stk'),
            'product_model_id': productModelId,
            'quantity': delta,
            'min_quantity': 0,
            'unit_cost': 0,
            'unit_price': 0,
            'created_at': DateTimeHelpers.toSql(now),
            'updated_at': DateTimeHelpers.toSql(now),
          });
          newQty = delta;
        } else {
          final currentQty = (rows.first['quantity'] as num?)?.toInt() ?? 0;
          final nextQty = currentQty + delta;
          if (nextQty < 0) {
            throw StateError('Stock cannot go below zero.');
          }
          await transaction.update(
            TableNames.inventoryStock,
            <String, Object?>{
              'quantity': nextQty,
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'product_model_id = ?',
            whereArgs: <Object?>[productModelId],
          );
          newQty = nextQty;
        }

        await transaction.insert(TableNames.stockAdjustments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'adj'),
          'product_model_id': productModelId,
          'serialized_stock_id': null,
          'adjustment_type': delta > 0 ? 'increase' : 'decrease',
          'quantity_delta': delta,
          'reason': reason.trim().toLowerCase(),
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });
      });

      return newQty;
    }, operation: 'apply_stock_adjustment');
  }

  Future<Result<void>> writeOffSerializedStock({
    required String serializedStockId,
    required String reason,
    String? notes,
  }) {
    return guard<void>(() async {
      _validateAdjustmentReason(reason);
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();

      await _appDatabase.runInTransaction<void>((transaction) async {
        final rows = await transaction.query(
          TableNames.serializedStock,
          columns: <String>['product_model_id', 'stock_status', 'imei1'],
          where: 'id = ?',
          whereArgs: <Object?>[serializedStockId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Serialized stock record not found.');
        }
        final row = rows.first;
        final status = row['stock_status'] as String? ?? '';
        if (status != 'in_stock') {
          throw StateError('Only in-stock IMEIs can be written off.');
        }

        await transaction.update(
          TableNames.serializedStock,
          <String, Object?>{
            'stock_status': 'damaged',
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[serializedStockId],
        );

        await transaction.insert(TableNames.stockAdjustments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'adj'),
          'product_model_id': row['product_model_id'] as String,
          'serialized_stock_id': serializedStockId,
          'adjustment_type': 'write_off',
          'quantity_delta': -1,
          'reason': reason.trim().toLowerCase(),
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });
      });
    }, operation: 'write_off_serialized_stock');
  }

  Future<Result<List<StockAdjustmentHistoryRowEntity>>> getStockAdjustments({
    int limit = 200,
    int offset = 0,
  }) {
    return guard<List<StockAdjustmentHistoryRowEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          sa.id,
          sa.created_at,
          pm.name AS product_name,
          sa.adjustment_type,
          sa.quantity_delta,
          sa.reason,
          sa.notes,
          ss.imei1
        FROM ${TableNames.stockAdjustments} sa
        JOIN ${TableNames.productModels} pm ON pm.id = sa.product_model_id
        LEFT JOIN ${TableNames.serializedStock} ss ON ss.id = sa.serialized_stock_id
        ORDER BY sa.created_at DESC
        LIMIT ? OFFSET ?
        ''',
        <Object?>[limit, offset],
      );
      return rows.map((row) {
        return StockAdjustmentHistoryRowEntity(
          id: row['id'] as String,
          createdAt: DateTimeHelpers.fromSql(row['created_at'] as String),
          productName: row['product_name'] as String,
          adjustmentType: row['adjustment_type'] as String,
          quantityDelta: (row['quantity_delta'] as num?)?.toInt() ?? 0,
          reason: row['reason'] as String? ?? '-',
          notes: row['notes'] as String?,
          imei: row['imei1'] as String?,
        );
      }).toList(growable: false);
    }, operation: 'stock_adjustment_history');
  }

  void _validateAdjustmentReason(String reason) {
    final normalized = reason.trim().toLowerCase();
    if (normalized != 'damage' &&
        normalized != 'theft' &&
        normalized != 'correction') {
      throw StateError('Reason must be damage, theft, or correction.');
    }
  }
}
