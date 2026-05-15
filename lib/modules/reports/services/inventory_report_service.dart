import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/customer_balance_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/low_stock_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/stock_report_row_entity.dart';

class InventoryReportService with BaseRepositoryGuard {
  InventoryReportService({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<List<StockReportRowEntity>>> getCurrentStockReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<StockReportRowEntity>>(() async {
      final productFilterValue = filter.productModelId?.trim();
      final productFilter = productFilterValue == null || productFilterValue.isEmpty
          ? null
          : productFilterValue;

      final rows = await QueryDiagnostics.trace(
        label: 'reports.current_stock',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          pm.name AS product_name,
          COALESCE(pm.category, '-') AS category,
          ist.quantity AS available_quantity,
          ist.min_quantity,
          ist.unit_cost,
          ist.unit_price,
          ist.location,
          CASE WHEN ist.quantity <= ist.min_quantity THEN 1 ELSE 0 END AS is_low_stock
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND (? IS NULL OR pm.id = ?)

        UNION ALL

        SELECT
          pm.name AS product_name,
          COALESCE(pm.category, '-') AS category,
          COUNT(*) AS available_quantity,
          0 AS min_quantity,
          COALESCE(AVG(ss.cost_price), 0) AS unit_cost,
          COALESCE(AVG(ss.selling_price), 0) AS unit_price,
          NULL AS location,
          0 AS is_low_stock
        FROM ${TableNames.serializedStock} ss
        JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
        WHERE pm.is_active = 1
          AND ss.stock_status = 'in_stock'
          AND (? IS NULL OR pm.id = ?)
        GROUP BY pm.id, pm.name, pm.category

        ORDER BY product_name COLLATE NOCASE ASC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[
            productFilter,
            productFilter,
            productFilter,
            productFilter,
            filter.pageSize,
            filter.offset,
          ],
        ),
      );

      return rows
          .map(
            (row) => StockReportRowEntity(
              productName: row['product_name'] as String,
              category: row['category'] as String,
              availableQuantity: (row['available_quantity'] as num?)?.toInt() ?? 0,
              minQuantity: (row['min_quantity'] as num?)?.toInt() ?? 0,
              unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
              unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
              location: row['location'] as String?,
              isLowStock: ((row['is_low_stock'] as num?)?.toInt() ?? 0) == 1,
            ),
          )
          .toList(growable: false);
    }, operation: 'current_stock_report');
  }

  Future<Result<List<LowStockReportRowEntity>>> getLowStockReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<LowStockReportRowEntity>>(() async {
      final args = <Object?>[];
      final where = StringBuffer('pm.is_active = 1 AND ist.quantity <= ist.min_quantity');
      final productFilter = filter.productModelId?.trim();
      if (productFilter != null && productFilter.isNotEmpty) {
        where.write(' AND pm.id = ?');
        args.add(productFilter);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.low_stock',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT pm.name, ist.quantity, ist.min_quantity, ist.location
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE ${where.toString()}
        ORDER BY ist.quantity ASC, pm.name COLLATE NOCASE ASC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[...args, filter.pageSize, filter.offset],
        ),
      );

      return rows
          .map(
            (row) => LowStockReportRowEntity(
              productName: row['name'] as String,
              quantity: (row['quantity'] as num?)?.toInt() ?? 0,
              minQuantity: (row['min_quantity'] as num?)?.toInt() ?? 0,
              location: row['location'] as String?,
            ),
          )
          .toList(growable: false);
    }, operation: 'low_stock_report');
  }

  Future<Result<List<CustomerBalanceReportRowEntity>>> getCustomerBalanceReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<CustomerBalanceReportRowEntity>>(() async {
      final args = <Object?>[];
      final where = StringBuffer('1 = 1');

      final start = filter.startDate;
      if (start != null) {
        final startUtc = DateTime.utc(start.year, start.month, start.day);
        where.write(' AND s.sale_date >= ?');
        args.add(startUtc.toIso8601String());
      }

      final end = filter.endDate;
      if (end != null) {
        final endUtc = DateTime.utc(end.year, end.month, end.day).add(
          const Duration(days: 1),
        );
        where.write(' AND s.sale_date < ?');
        args.add(endUtc.toIso8601String());
      }

      final customerId = filter.customerId?.trim();
      if (customerId != null && customerId.isNotEmpty) {
        where.write(' AND s.customer_id = ?');
        args.add(customerId);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.customer_balance',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          COALESCE(SUM(s.total), 0) AS total_sales,
          COALESCE(SUM(s.paid_amount), 0) AS total_paid,
          COALESCE(SUM(CASE
            WHEN s.total > s.paid_amount THEN s.total - s.paid_amount
            ELSE 0
          END), 0) AS pending_balance
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE ${where.toString()}
        GROUP BY customer_name
        HAVING pending_balance > 0
        ORDER BY pending_balance DESC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[...args, filter.pageSize, filter.offset],
        ),
      );

      return rows
          .map(
            (row) => CustomerBalanceReportRowEntity(
              customerName: row['customer_name'] as String,
              totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
              totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0,
              pendingBalance: (row['pending_balance'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false);
    }, operation: 'customer_balance_report');
  }
}
