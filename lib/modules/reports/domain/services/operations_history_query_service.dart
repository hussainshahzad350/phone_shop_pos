import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class OperationsHistoryQueryService with BaseRepositoryGuard {
  OperationsHistoryQueryService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  }) : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<List<SalesHistoryRowEntity>>> searchSalesHistory({
    required String invoiceQuery,
    required String customerQuery,
    required DateTime? startDate,
    required DateTime? endDate,
    bool pendingOnly = false,
    bool collectibleOnly = false,
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
        final startUtc =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('s.sale_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('s.sale_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      if (pendingOnly || collectibleOnly) {
        whereClauses.add('s.paid_amount < s.total');
      }

      if (collectibleOnly) {
        whereClauses.add("s.payment_method = 'credit'");
        whereClauses.add(
          "s.customer_id IS NOT NULL AND TRIM(s.customer_id) != '' AND LOWER(s.customer_id) != 'walk_in'",
        );
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
          paymentMethod:
              PaymentMethod.normalizeNullable(row['payment_method'] as String?),
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
          paymentMethod: PaymentMethod.normalizeNullable(
              header['payment_method'] as String?),
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
          'COALESCE(sp.phone, \'\') LIKE ? OR COALESCE(sp.id, \'\') LIKE ? OR '
          'EXISTS ('
          'SELECT 1 FROM ${TableNames.purchaseItems} qpi '
          'JOIN ${TableNames.serializedStock} qss '
          'ON qss.id = qpi.serialized_stock_id '
          'WHERE qpi.purchase_id = p.id '
          'AND COALESCE(qss.seller_name, \'\') LIKE ?'
          '))',
        );
        args
          ..add('%$trimmedSupplier%')
          ..add('%$trimmedSupplier%')
          ..add('%$trimmedSupplier%')
          ..add('%$trimmedSupplier%');
      }

      if (startDate != null) {
        final startUtc =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
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
            (
              SELECT ss.seller_name
              FROM ${TableNames.purchaseItems} pi
              JOIN ${TableNames.serializedStock} ss
                ON ss.id = pi.serialized_stock_id
              WHERE pi.purchase_id = p.id
                AND ss.seller_name IS NOT NULL
                AND TRIM(ss.seller_name) != ''
              ORDER BY pi.created_at ASC
              LIMIT 1
            ) AS seller_name,
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
          sellerName: row['seller_name'] as String?,
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
          (
            SELECT ss.seller_name
            FROM ${TableNames.purchaseItems} pi
            JOIN ${TableNames.serializedStock} ss
              ON ss.id = pi.serialized_stock_id
            WHERE pi.purchase_id = p.id
              AND ss.seller_name IS NOT NULL
              AND TRIM(ss.seller_name) != ''
            ORDER BY pi.created_at ASC
            LIMIT 1
          ) AS seller_name,
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
          pi.id AS purchase_item_id,
          pi.product_model_id,
          pm.name AS product_name,
          pm.has_imei,
          pi.quantity,
          pi.unit_cost,
          pi.line_total,
          pi.serialized_stock_id,
          ss.imei1,
          COALESCE((
            SELECT SUM(pr.return_qty)
            FROM ${TableNames.purchaseReturns} pr
            WHERE pr.purchase_item_id = pi.id
          ), 0) AS returned_qty
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
          purchaseDate:
              DateTimeHelpers.fromSql(header['purchase_date'] as String),
          supplierName: header['supplier_name'] as String,
          sellerName: header['seller_name'] as String?,
          invoiceNumber: header['invoice_number'] as String?,
          total: (header['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (header['paid_amount'] as num?)?.toDouble() ?? 0,
        ),
        items: itemRows.map((row) {
          return PurchaseHistoryItemEntity(
            purchaseItemId: row['purchase_item_id'] as String,
            productModelId: row['product_model_id'] as String,
            productName: row['product_name'] as String,
            hasImei: ((row['has_imei'] as num?)?.toInt() ?? 0) == 1,
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
            unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
            lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
            serializedStockId: row['serialized_stock_id'] as String?,
            imei: row['imei1'] as String?,
            returnedQty: (row['returned_qty'] as num?)?.toInt() ?? 0,
          );
        }).toList(growable: false),
        notes: header['notes'] as String?,
      );
    }, operation: 'get_purchase_history_detail');
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
}
