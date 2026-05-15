import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_report_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';

class ProfitReportService with BaseRepositoryGuard {
  ProfitReportService({required AppDatabase appDatabase}) : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<ProfitReportEntity>> getProfitReport(ReportFilterEntity filter) {
    return guard<ProfitReportEntity>(() async {
      final args = <Object?>[];
      final where = _buildWhereClause(filter, args: args);

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE(SUM(si.line_total), 0) AS total_revenue,
          COALESCE(SUM(si.cost_price * si.quantity), 0) AS total_cost
        FROM ${TableNames.sales} s
        JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
        WHERE $where
        ''',
        args,
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

  String _buildWhereClause(ReportFilterEntity filter, {required List<Object?> args}) {
    final clauses = <String>['1 = 1'];

    final start = filter.startDate;
    if (start != null) {
      final startUtc = DateTime.utc(start.year, start.month, start.day);
      clauses.add('s.sale_date >= ?');
      args.add(DateTimeHelpers.toSql(startUtc));
    }

    final end = filter.endDate;
    if (end != null) {
      final endUtc = DateTime.utc(end.year, end.month, end.day).add(
        const Duration(days: 1),
      );
      clauses.add('s.sale_date < ?');
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
      clauses.add('si.product_model_id = ?');
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
