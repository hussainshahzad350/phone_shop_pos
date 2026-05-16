import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';

class DashboardService with BaseRepositoryGuard {
  DashboardService({required AppDatabase appDatabase}) : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<DashboardKpisEntity>> getDashboardKpis() {
    return guard<DashboardKpisEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final salesRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE(SUM(s.total), 0) AS today_sales,
          COALESCE(SUM(CASE
            WHEN pm.has_imei = 1 THEN 1
            ELSE 0
          END), 0) AS phones_sold,
          COALESCE(SUM(CASE
            WHEN pm.has_imei = 0 THEN si.quantity
            ELSE 0
          END), 0) AS accessories_sold,
          COALESCE(SUM(
            si.line_total - (si.cost_price * si.quantity)
          ), 0) AS today_profit
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.saleItems} si ON si.sale_id = s.id
        LEFT JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.sale_date >= ? AND s.sale_date < ?
        ''',
        <Object?>[DateTimeHelpers.toSql(start), DateTimeHelpers.toSql(end)],
      );

      final stockRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE((
            SELECT COUNT(*)
            FROM ${TableNames.inventoryStock} ist
            JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
            WHERE pm.is_active = 1 AND pm.has_imei = 0 AND ist.quantity <= ist.min_quantity
          ), 0) AS low_stock_count,
          COALESCE((
            SELECT SUM(ist.quantity)
            FROM ${TableNames.inventoryStock} ist
            JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
            WHERE pm.is_active = 1 AND pm.has_imei = 0
          ), 0)
          + COALESCE((
            SELECT COUNT(*)
            FROM ${TableNames.serializedStock} ss
            JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
            WHERE pm.is_active = 1 AND ss.stock_status = 'in_stock'
          ), 0) AS available_stock_count,
          COALESCE((
            SELECT SUM(CASE
              WHEN s.total > s.paid_amount THEN s.total - s.paid_amount
              ELSE 0
            END)
            FROM ${TableNames.sales} s
          ), 0) AS pending_balances
        ''',
      );

      final sales = salesRows.first;
      final stock = stockRows.first;

      return DashboardKpisEntity(
        todaySales: (sales['today_sales'] as num?)?.toDouble() ?? 0,
        todayProfit: (sales['today_profit'] as num?)?.toDouble() ?? 0,
        phonesSoldToday: (sales['phones_sold'] as num?)?.toInt() ?? 0,
        accessoriesSoldToday: (sales['accessories_sold'] as num?)?.toInt() ?? 0,
        lowStockCount: (stock['low_stock_count'] as num?)?.toInt() ?? 0,
        availableStockCount: (stock['available_stock_count'] as num?)?.toInt() ?? 0,
        pendingBalances: (stock['pending_balances'] as num?)?.toDouble() ?? 0,
      );
    }, operation: 'get_dashboard_kpis');
  }

  Future<Result<List<DashboardRecentSaleEntity>>> getRecentSales({int limit = 10}) {
    return guard<List<DashboardRecentSaleEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          s.invoice_number,
          s.sale_date,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          s.total,
          s.paid_amount,
          s.payment_method
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        ORDER BY s.sale_date DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      return rows
          .map(
            (row) => DashboardRecentSaleEntity(
              invoiceNumber: row['invoice_number'] as String,
              saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
              customerName: row['customer_name'] as String,
              total: (row['total'] as num?)?.toDouble() ?? 0,
              paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
              paymentMethod: row['payment_method'] as String?,
            ),
          )
          .toList(growable: false);
    }, operation: 'get_recent_sales');
  }

  Future<Result<List<DashboardLowStockEntity>>> getLowStockWarnings({int limit = 8}) {
    return guard<List<DashboardLowStockEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          pm.name,
          ist.quantity,
          ist.min_quantity,
          ist.location
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND pm.has_imei = 0 AND ist.quantity <= ist.min_quantity
        ORDER BY ist.quantity ASC, pm.name COLLATE NOCASE ASC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      return rows
          .map(
            (row) => DashboardLowStockEntity(
              productName: row['name'] as String,
              quantity: (row['quantity'] as num?)?.toInt() ?? 0,
              minQuantity: (row['min_quantity'] as num?)?.toInt() ?? 0,
              location: row['location'] as String?,
            ),
          )
          .toList(growable: false);
    }, operation: 'get_low_stock_warnings');
  }
}
