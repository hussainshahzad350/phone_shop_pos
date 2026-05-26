import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/daily_sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sold_phone_report_row_entity.dart';

class SalesReportService with BaseRepositoryGuard {
  SalesReportService({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<List<DailySalesReportRowEntity>>> getDailySalesReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<DailySalesReportRowEntity>>(() async {
      final saleArgs = <Object?>[];
      final returnArgs = <Object?>[];
      final saleWhere = _buildSalesWhereClause(
        filter,
        args: saleArgs,
        dateColumn: 's.sale_date',
      );
      final returnWhere = _buildSalesWhereClause(
        filter,
        args: returnArgs,
        dateColumn: 'sr.created_at',
        productModelMatchColumn: 'si.product_model_id',
      );

      final rows = await QueryDiagnostics.trace(
        label: 'reports.daily_sales',
        action: () => _appDatabase.database.rawQuery(
          '''
        WITH sale_return_totals AS (
          SELECT
            sale_id,
            COALESCE(SUM(return_amount), 0) AS returned_total
          FROM ${TableNames.saleReturns}
          GROUP BY sale_id
        ),
        sale_events AS (
          SELECT
            date(s.sale_date) AS event_day,
            1 AS invoice_count,
            COALESCE(s.total + COALESCE(srt.returned_total, 0), 0) AS total_sales,
            COALESCE(SUM(
              si.line_total - (si.cost_price * si.quantity)
            ), 0) AS total_profit,
            COALESCE(SUM(CASE WHEN pm.has_imei = 1 THEN 1 ELSE 0 END), 0) AS phones_sold,
            COALESCE(SUM(CASE WHEN pm.has_imei = 0 THEN si.quantity ELSE 0 END), 0) AS accessories_sold,
            COALESCE(CASE
              WHEN s.total > s.paid_amount THEN s.total - s.paid_amount
              ELSE 0
            END, 0) AS pending_balances
          FROM ${TableNames.sales} s
          LEFT JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
          LEFT JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
          LEFT JOIN sale_return_totals srt ON srt.sale_id = s.id
          WHERE $saleWhere
          GROUP BY s.id, event_day, s.total, s.paid_amount, srt.returned_total
        ),
        return_events AS (
          SELECT
            date(sr.created_at) AS event_day,
            0 AS invoice_count,
            -COALESCE(SUM(sr.return_amount), 0) AS total_sales,
            COALESCE(SUM(
              (sr.cost_price * sr.return_qty) - sr.return_amount
            ), 0) AS total_profit,
            0 AS phones_sold,
            0 AS accessories_sold,
            0 AS pending_balances
          FROM ${TableNames.saleReturns} sr
          JOIN ${TableNames.sales} s ON s.id = sr.sale_id
          JOIN ${TableNames.saleItems} si ON si.id = sr.sale_item_id
          WHERE $returnWhere
          GROUP BY date(sr.created_at)
        )
        SELECT
          event_day AS sale_day,
          COALESCE(SUM(invoice_count), 0) AS invoice_count,
          COALESCE(SUM(total_sales), 0) AS total_sales,
          COALESCE(SUM(total_profit), 0) AS total_profit,
          COALESCE(SUM(phones_sold), 0) AS phones_sold,
          COALESCE(SUM(accessories_sold), 0) AS accessories_sold,
          COALESCE(SUM(pending_balances), 0) AS pending_balances
        FROM (
          SELECT * FROM sale_events
          UNION ALL
          SELECT * FROM return_events
        ) report_events
        GROUP BY event_day
        ORDER BY event_day DESC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[
            ...saleArgs,
            ...returnArgs,
            filter.pageSize,
            filter.offset,
          ],
        ),
      );

      return rows
          .map(
            (row) => DailySalesReportRowEntity(
              day: row['sale_day'] as String,
              invoiceCount: (row['invoice_count'] as num?)?.toInt() ?? 0,
              totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
              totalProfit: (row['total_profit'] as num?)?.toDouble() ?? 0,
              phonesSold: (row['phones_sold'] as num?)?.toInt() ?? 0,
              accessoriesSold: (row['accessories_sold'] as num?)?.toInt() ?? 0,
              pendingBalances:
                  (row['pending_balances'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false);
    }, operation: 'daily_sales_report');
  }

  Future<Result<List<SalesReportRowEntity>>> getDateRangeSalesReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<SalesReportRowEntity>>(() async {
      final args = <Object?>[];
      final where = _buildSalesWhereClause(
        filter,
        args: args,
        dateColumn: 's.sale_date',
      );

      final rows = await QueryDiagnostics.trace(
        label: 'reports.date_range_sales',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          s.invoice_number,
          s.sale_date,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          s.total,
          s.paid_amount,
          s.payment_method,
          CASE WHEN s.paid_amount >= s.total THEN 'paid' ELSE 'pending' END AS status
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE $where
        ORDER BY s.sale_date DESC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[...args, filter.pageSize, filter.offset],
        ),
      );

      return rows
          .map(
            (row) => SalesReportRowEntity(
              invoiceNumber: row['invoice_number'] as String,
              saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
              customerName: row['customer_name'] as String,
              total: (row['total'] as num?)?.toDouble() ?? 0,
              paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
              paymentMethod: row['payment_method'] as String?,
              status: row['status'] as String,
            ),
          )
          .toList(growable: false);
    }, operation: 'date_range_sales_report');
  }

  Future<Result<List<SoldPhoneReportRowEntity>>> getSoldPhonesReport(
    ReportFilterEntity filter,
  ) {
    return guard<List<SoldPhoneReportRowEntity>>(() async {
      final args = <Object?>[];
      final where = _buildSalesWhereClause(
        filter,
        args: args,
        dateColumn: 's.sale_date',
      );

      final rows = await QueryDiagnostics.trace(
        label: 'reports.sold_phones',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          s.invoice_number,
          s.sale_date,
          pm.name AS product_name,
          COALESCE(ss.imei1, '-') AS imei,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          si.line_total AS sale_price,
          COALESCE(si.cost_price, 0) AS cost_price
        FROM ${TableNames.sales} s
        JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        LEFT JOIN ${TableNames.serializedStock} ss ON ss.id = si.serialized_stock_id
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE $where
          AND pm.has_imei = 1
          AND NOT EXISTS (
            SELECT 1
            FROM ${TableNames.saleReturns} sr
            WHERE sr.sale_item_id = si.id
              AND sr.return_qty >= si.quantity
          )
        ORDER BY s.sale_date DESC
        LIMIT ? OFFSET ?
        ''',
          <Object?>[...args, filter.pageSize, filter.offset],
        ),
      );

      return rows
          .map(
            (row) => SoldPhoneReportRowEntity(
              invoiceNumber: row['invoice_number'] as String,
              saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
              productName: row['product_name'] as String,
              imei: row['imei'] as String,
              customerName: row['customer_name'] as String,
              salePrice: (row['sale_price'] as num?)?.toDouble() ?? 0,
              costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false);
    }, operation: 'sold_phones_report');
  }

  String _buildSalesWhereClause(
    ReportFilterEntity filter, {
    required List<Object?> args,
    required String dateColumn,
    String? productModelMatchColumn,
  }) {
    final clauses = <String>['1 = 1'];

    final start = filter.startDate;
    if (start != null) {
      final startUtc = DateTime.utc(start.year, start.month, start.day);
      clauses.add('$dateColumn >= ?');
      args.add(DateTimeHelpers.toSql(startUtc));
    }

    final end = filter.endDate;
    if (end != null) {
      final endUtc = DateTime.utc(end.year, end.month, end.day).add(
        const Duration(days: 1),
      );
      clauses.add('$dateColumn < ?');
      args.add(DateTimeHelpers.toSql(endUtc));
    }

    final customerId = filter.customerId?.trim();
    if (customerId != null && customerId.isNotEmpty) {
      clauses.add('s.customer_id = ?');
      args.add(customerId);
    }

    final paymentMethod = filter.paymentMethod?.trim();
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      clauses.add('s.payment_method = ?');
      args.add(paymentMethod);
    }

    final productModelId = filter.productModelId?.trim();
    if (productModelId != null && productModelId.isNotEmpty) {
      if (productModelMatchColumn != null) {
        clauses.add('$productModelMatchColumn = ?');
      } else {
        clauses.add(
          'EXISTS (SELECT 1 FROM ${TableNames.saleItems} x WHERE x.sale_id = s.id AND x.product_model_id = ?)',
        );
      }
      args.add(productModelId);
    }

    final status = filter.status?.trim();
    if (status == 'paid') {
      clauses.add('s.paid_amount >= s.total');
    } else if (status == 'pending') {
      clauses.add('s.paid_amount < s.total');
    }

    return clauses.join(' AND ');
  }
}
