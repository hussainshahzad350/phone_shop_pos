import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_report_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';

class ProfitReportService with BaseRepositoryGuard {
  ProfitReportService({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<ProfitReportEntity>> getProfitReport(
      ReportFilterEntity filter) {
    return guard<ProfitReportEntity>(() async {
      final saleArgs = <Object?>[];
      final returnArgs = <Object?>[];
      final saleWhere = _buildWhereClause(
        filter,
        args: saleArgs,
        dateColumn: 's.sale_date',
      );
      final returnWhere = _buildWhereClause(
        filter,
        args: returnArgs,
        dateColumn: 'sr.created_at',
        productModelColumn: 'si.product_model_id',
      );

      final rows = await QueryDiagnostics.trace(
        label: 'reports.profit',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(SUM(revenue_delta), 0) AS total_revenue,
          COALESCE(SUM(cost_delta), 0) AS total_cost
        FROM (
          SELECT
            si.line_total
              - COALESCE(s.discount * si.line_total / NULLIF(s.subtotal, 0), 0)
              AS revenue_delta,
            si.cost_price * si.quantity AS cost_delta
          FROM ${TableNames.sales} s
          JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
          WHERE $saleWhere

          UNION ALL

          SELECT
            -sr.return_amount AS revenue_delta,
            -(sr.cost_price * sr.return_qty) AS cost_delta
          FROM ${TableNames.saleReturns} sr
          JOIN ${TableNames.sales} s ON s.id = sr.sale_id
          JOIN ${TableNames.saleItems} si ON si.id = sr.sale_item_id
          WHERE $returnWhere
        ) profit_events
        ''',
          <Object?>[...saleArgs, ...returnArgs],
        ),
      );

      final row = rows.first;
      final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      final cost = (row['total_cost'] as num?)?.toDouble() ?? 0;

      return ProfitReportEntity(
        totalRevenue: revenue,
        totalCost: cost,
        totalProfit: revenue - cost,
      );
    }, operation: 'profit_report');
  }

  Future<Result<List<ProfitRowEntity>>> getProfitReportRows(
    ReportFilterEntity filter,
  ) {
    return guard<List<ProfitRowEntity>>(() async {
      final saleArgs = <Object?>[];
      final returnArgs = <Object?>[];
      final saleWhere = _buildWhereClause(
        filter,
        args: saleArgs,
        dateColumn: 's.sale_date',
      );
      final returnWhere = _buildWhereClause(
        filter,
        args: returnArgs,
        dateColumn: 'sr.created_at',
        productModelColumn: 'si.product_model_id',
      );

      final rows = await QueryDiagnostics.trace(
        label: 'reports.profit_rows',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          event_day,
          COALESCE(SUM(revenue_delta), 0)     AS total_revenue,
          COALESCE(SUM(cost_delta), 0)        AS total_cost,
          COALESCE(SUM(phones_delta), 0)      AS phones_sold,
          COALESCE(SUM(accessories_delta), 0) AS accessories_sold
        FROM (
          SELECT
            date(s.sale_date) AS event_day,
            si.line_total
              - COALESCE(s.discount * si.line_total / NULLIF(s.subtotal, 0), 0)
              AS revenue_delta,
            si.cost_price * si.quantity AS cost_delta,
            CASE WHEN pm.has_imei = 1 THEN 1      ELSE 0 END AS phones_delta,
            CASE WHEN pm.has_imei = 0 THEN si.quantity ELSE 0 END AS accessories_delta
          FROM ${TableNames.sales} s
          JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
          JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
          WHERE $saleWhere

          UNION ALL

          SELECT
            date(sr.created_at) AS event_day,
            -sr.return_amount   AS revenue_delta,
            -(sr.cost_price * sr.return_qty) AS cost_delta,
            CASE WHEN pm.has_imei = 1 THEN -sr.return_qty ELSE 0 END AS phones_delta,
            CASE WHEN pm.has_imei = 0 THEN -sr.return_qty ELSE 0 END AS accessories_delta
          FROM ${TableNames.saleReturns} sr
          JOIN ${TableNames.sales} s  ON s.id  = sr.sale_id
          JOIN ${TableNames.saleItems} si ON si.id = sr.sale_item_id
          JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
          WHERE $returnWhere
        ) profit_events
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
            (row) => ProfitRowEntity(
              day: row['event_day'] as String,
              phonesSold: (row['phones_sold'] as num?)?.toInt() ?? 0,
              accessoriesSold: (row['accessories_sold'] as num?)?.toInt() ?? 0,
              totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0,
              totalCost: (row['total_cost'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false);
    }, operation: 'profit_report_rows');
  }

  String _buildWhereClause(
    ReportFilterEntity filter, {
    required List<Object?> args,
    required String dateColumn,
    String? productModelColumn,
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
      clauses.add('${productModelColumn ?? 'si.product_model_id'} = ?');
      args.add(productModelId);
    }

    final status = filter.status?.trim();
    if (status == 'paid') {
      clauses.add('s.paid_amount >= s.total');
    } else if (status == 'pending') {
      clauses.add('s.paid_amount < s.total');
    }

    final itemType = filter.itemType;
    if (itemType == 'phones') {
      clauses.add(
        'si.product_model_id IN'
        ' (SELECT id FROM ${TableNames.productModels} WHERE has_imei = 1)',
      );
    } else if (itemType == 'accessories') {
      clauses.add(
        'si.product_model_id IN'
        ' (SELECT id FROM ${TableNames.productModels} WHERE has_imei = 0)',
      );
    }

    return clauses.join(' AND ');
  }
}
