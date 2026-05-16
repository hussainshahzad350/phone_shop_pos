import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';

class DashboardService with BaseRepositoryGuard {
  DashboardService({
    required AppDatabase appDatabase,
    DateTime Function()? nowProvider,
  })  : _appDatabase = appDatabase,
        _nowProvider = nowProvider ?? DateTimeHelpers.nowUtc;

  final AppDatabase _appDatabase;
  final DateTime Function() _nowProvider;
  static const Duration _kpiCacheTtl = Duration(seconds: 20);

  DashboardKpisEntity? _cachedKpis;
  DateTime? _cachedKpisAt;
  Future<Result<DashboardKpisEntity>>? _inFlightKpisRequest;

  /// Clears the in-memory KPI cache, forcing the next [getDashboardKpis] call
  /// to re-query the database. Useful in tests and after mutations.
  void clearCache() {
    _cachedKpis = null;
    _cachedKpisAt = null;
    _inFlightKpisRequest = null;
  }

  Future<Result<DashboardKpisEntity>> getDashboardKpis() async {
    final now = _nowProvider();
    final cached = _cachedKpis;
    final cachedAt = _cachedKpisAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _kpiCacheTtl) {
      return Success<DashboardKpisEntity>(cached);
    }

    final inFlight = _inFlightKpisRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final request = guard<DashboardKpisEntity>(() async {
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final salesRows = await QueryDiagnostics.trace(
        label: 'dashboard.today_sales',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(SUM(s.total), 0) AS today_sales
        FROM ${TableNames.sales} s
        WHERE s.sale_date >= ? AND s.sale_date < ?
        ''',
          <Object?>[DateTimeHelpers.toSql(start), DateTimeHelpers.toSql(end)],
        ),
      );

      final itemRows = await QueryDiagnostics.trace(
        label: 'dashboard.today_item_aggregates',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(SUM(CASE WHEN pm.has_imei = 1 THEN 1 ELSE 0 END), 0) AS phones_sold,
          COALESCE(SUM(CASE WHEN pm.has_imei = 0 THEN si.quantity ELSE 0 END), 0) AS accessories_sold,
          COALESCE(SUM(
            si.line_total - (si.cost_price * si.quantity)
            - COALESCE(ri.return_amount, 0) + COALESCE(ri.return_cost, 0)
          ), 0) AS today_profit
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        LEFT JOIN (
          SELECT sale_item_id,
                 SUM(return_amount) AS return_amount,
                 SUM(cost_price * return_qty) AS return_cost
          FROM ${TableNames.saleReturns}
          GROUP BY sale_item_id
        ) ri ON ri.sale_item_id = si.id
        WHERE s.sale_date >= ? AND s.sale_date < ?
        ''',
          <Object?>[DateTimeHelpers.toSql(start), DateTimeHelpers.toSql(end)],
        ),
      );

      final stockRows = await QueryDiagnostics.trace(
        label: 'dashboard.stock_aggregates',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(SUM(CASE WHEN ist.quantity <= ist.min_quantity THEN 1 ELSE 0 END), 0) AS low_stock_count,
          COALESCE(SUM(ist.quantity), 0) AS accessory_units
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND pm.has_imei = 0
        ''',
        ),
      );

      final serializedRows = await QueryDiagnostics.trace(
        label: 'dashboard.in_stock_serialized_count',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT COALESCE(COUNT(*), 0) AS in_stock_serialized
        FROM ${TableNames.serializedStock} ss
        JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
        WHERE pm.is_active = 1 AND ss.stock_status = 'in_stock'
        ''',
        ),
      );

      final pendingRows = await QueryDiagnostics.trace(
        label: 'dashboard.pending_balances',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          COALESCE(SUM(CASE
            WHEN s.total > s.paid_amount THEN s.total - s.paid_amount
            ELSE 0
          END), 0) AS pending_balances
        FROM ${TableNames.sales} s
        ''',
        ),
      );

      final sales = salesRows.first;
      final items = itemRows.first;
      final stock = stockRows.first;
      final serialized = serializedRows.first;
      final pending = pendingRows.first;

      final entity = DashboardKpisEntity(
        todaySales: (sales['today_sales'] as num?)?.toDouble() ?? 0,
        todayProfit: (items['today_profit'] as num?)?.toDouble() ?? 0,
        phonesSoldToday: (items['phones_sold'] as num?)?.toInt() ?? 0,
        accessoriesSoldToday: (items['accessories_sold'] as num?)?.toInt() ?? 0,
        lowStockCount: (stock['low_stock_count'] as num?)?.toInt() ?? 0,
        availableStockCount:
            ((stock['accessory_units'] as num?)?.toInt() ?? 0) +
                ((serialized['in_stock_serialized'] as num?)?.toInt() ?? 0),
        pendingBalances: (pending['pending_balances'] as num?)?.toDouble() ?? 0,
      );

      _cachedKpis = entity;
      _cachedKpisAt = now;
      return entity;
    }, operation: 'get_dashboard_kpis');

    _inFlightKpisRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightKpisRequest, request)) {
        _inFlightKpisRequest = null;
      }
    }
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
