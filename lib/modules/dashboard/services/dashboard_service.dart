import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_return_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/model_imei_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dealer_stock_breakdown_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_balance_customer_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/daily_sales_point_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_range.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_transaction_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/range_sales_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/sidebar_insights_entity.dart';

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
      // "Today" is the shop's local calendar day. now is a UTC instant, so
      // take its local date and convert that day's midnight back to UTC.
      final localNow = now.toLocal();
      final start =
          DateTime(localNow.year, localNow.month, localNow.day).toUtc();
      final end = start.add(const Duration(days: 1));

      final salesRows = await QueryDiagnostics.trace(
        label: 'dashboard.today_sales',
        action: () => _appDatabase.database.rawQuery(
          '''
        WITH sale_return_totals AS (
          SELECT
            sale_id,
            COALESCE(SUM(return_amount), 0) AS returned_total
          FROM ${TableNames.saleReturns}
          GROUP BY sale_id
        ),
        return_events AS (
          SELECT
            COALESCE(SUM(return_amount), 0) AS returned_today
          FROM ${TableNames.saleReturns}
          WHERE created_at >= ? AND created_at < ?
        )
        SELECT
          COALESCE(SUM(s.total + COALESCE(srt.returned_total, 0)), 0)
            - COALESCE((SELECT returned_today FROM return_events), 0)
            AS today_sales
        FROM ${TableNames.sales} s
        LEFT JOIN sale_return_totals srt ON srt.sale_id = s.id
        WHERE s.sale_date >= ? AND s.sale_date < ?
          AND s.status = 'posted'
        ''',
          <Object?>[
            DateTimeHelpers.toSql(start),
            DateTimeHelpers.toSql(end),
            DateTimeHelpers.toSql(start),
            DateTimeHelpers.toSql(end),
          ],
        ),
      );

      final itemRows = await QueryDiagnostics.trace(
        label: 'dashboard.today_item_aggregates',
        action: () => _appDatabase.database.rawQuery(
          '''
        WITH return_events AS (
          SELECT
            COALESCE(SUM(sr.return_amount), 0) AS returned_revenue,
            COALESCE(SUM(sr.cost_price * sr.return_qty), 0) AS returned_cost
          FROM ${TableNames.saleReturns} sr
          WHERE sr.created_at >= ? AND sr.created_at < ?
        )
        SELECT
          COALESCE(SUM(CASE WHEN pm.has_imei = 1 THEN 1 ELSE 0 END), 0) AS phones_sold,
          COALESCE(SUM(CASE WHEN pm.has_imei = 0 THEN si.quantity ELSE 0 END), 0) AS accessories_sold,
          COALESCE(SUM(
            (si.line_total
              - COALESCE(s.discount * si.line_total / NULLIF(s.subtotal, 0), 0))
            - (si.cost_price * si.quantity)
          ), 0)
            - COALESCE((SELECT returned_revenue FROM return_events), 0)
            + COALESCE((SELECT returned_cost FROM return_events), 0)
            AS today_profit
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.sale_date >= ? AND s.sale_date < ?
          AND s.status = 'posted'
        ''',
          <Object?>[
            DateTimeHelpers.toSql(start),
            DateTimeHelpers.toSql(end),
            DateTimeHelpers.toSql(start),
            DateTimeHelpers.toSql(end),
          ],
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
        WHERE s.status = 'posted'
        ''',
        ),
      );

      final stockWorthRows = await QueryDiagnostics.trace(
        label: 'dashboard.total_stock_worth',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          (
            COALESCE((
              SELECT SUM(
                ist.quantity *
                COALESCE(NULLIF(ist.unit_cost, 0), pm.purchase_price, 0)
              )
              FROM ${TableNames.inventoryStock} ist
              JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
              WHERE pm.is_active = 1 AND pm.has_imei = 0
            ), 0)
            +
            COALESCE((
              SELECT SUM(
                COALESCE(NULLIF(ss.cost_price, 0), pm.purchase_price, 0)
              )
              FROM ${TableNames.serializedStock} ss
              JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
              WHERE pm.is_active = 1 AND ss.stock_status = 'in_stock'
            ), 0)
          ) AS total_stock_worth
        ''',
        ),
      );

      final dealerCountRows = await QueryDiagnostics.trace(
        label: 'dashboard.dealer_stock_count',
        action: () => _appDatabase.database.rawQuery(
          'SELECT COALESCE(COUNT(*), 0) AS dealer_count '
          'FROM ${TableNames.serializedStock} '
          'WHERE stock_status = ?',
          <Object?>['with_dealer'],
        ),
      );

      final repairsRows = await QueryDiagnostics.trace(
        label: 'dashboard.repairs_in_progress',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT COALESCE(COUNT(*), 0) AS repairs_in_progress
        FROM ${TableNames.repairJobs}
        WHERE is_deleted = 0
          AND status NOT IN ('delivered', 'cancelled')
        ''',
        ),
      );

      final sales = salesRows.first;
      final items = itemRows.first;
      final stock = stockRows.first;
      final serialized = serializedRows.first;
      final pending = pendingRows.first;
      final stockWorth = stockWorthRows.first;

      final entity = DashboardKpisEntity(
        todaySales: _asDouble(sales['today_sales']),
        todayProfit: _asDouble(items['today_profit']),
        phonesSoldToday: _asInt(items['phones_sold']),
        accessoriesSoldToday: _asInt(items['accessories_sold']),
        lowStockCount: _asInt(stock['low_stock_count']),
        availableStockCount: _asInt(stock['accessory_units']) +
            _asInt(serialized['in_stock_serialized']),
        pendingBalances: _asDouble(pending['pending_balances']),
        totalStockWorth: _asDouble(stockWorth['total_stock_worth']),
        dealerStockCount: _asInt(dealerCountRows.first['dealer_count']),
        repairsInProgress: _asInt(repairsRows.first['repairs_in_progress']),
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

  Future<Result<List<DashboardRecentSaleEntity>>> getRecentSales(
      {int limit = 10}) {
    return guard<List<DashboardRecentSaleEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          s.id AS sale_id,
          s.invoice_number,
          s.sale_date,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          s.total,
          s.paid_amount,
          s.payment_method
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE s.status = 'posted'
        ORDER BY s.sale_date DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      return rows.map(
        (row) {
          final rawSaleId = row['sale_id'] ?? row['id'];
          return DashboardRecentSaleEntity(
            saleId: rawSaleId?.toString(),
            invoiceNumber: row['invoice_number'] as String,
            saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
            customerName: row['customer_name'] as String,
            total: (row['total'] as num?)?.toDouble() ?? 0,
            paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
            paymentMethod: row['payment_method'] as String?,
          );
        },
      ).toList(growable: false);
    }, operation: 'get_recent_sales');
  }

  Future<Result<List<DashboardLowStockEntity>>> getLowStockWarnings(
      {int limit = 8}) {
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

  Future<Result<List<DashboardRecentSaleEntity>>> getTodaySalesDetails() {
    return guard<List<DashboardRecentSaleEntity>>(() async {
      final now = _nowProvider();
      final localNow = now.toLocal();
      final start =
          DateTime(localNow.year, localNow.month, localNow.day).toUtc();
      final end = start.add(const Duration(days: 1));

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          s.id AS sale_id,
          s.invoice_number,
          s.sale_date,
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          s.total,
          s.paid_amount,
          s.payment_method
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE s.status = 'posted'
          AND s.sale_date >= ? AND s.sale_date < ?
        ORDER BY s.sale_date DESC
        ''',
        <Object?>[DateTimeHelpers.toSql(start), DateTimeHelpers.toSql(end)],
      );

      return rows
          .map((row) => DashboardRecentSaleEntity(
                saleId: row['sale_id']?.toString(),
                invoiceNumber: row['invoice_number'] as String,
                saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
                customerName: row['customer_name'] as String,
                total: (row['total'] as num?)?.toDouble() ?? 0,
                paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
                paymentMethod: row['payment_method'] as String?,
              ))
          .toList(growable: false);
    }, operation: 'get_today_sales_details');
  }

  Future<Result<List<PendingBalanceCustomerEntity>>> getPendingBalanceDetails() {
    return guard<List<PendingBalanceCustomerEntity>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE(c.name, 'Walk-in Customer') AS customer_name,
          s.invoice_number,
          s.total,
          s.paid_amount,
          s.sale_date
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE s.status = 'posted'
          AND s.total > s.paid_amount
        ORDER BY (s.total - s.paid_amount) DESC
        LIMIT 50
        ''',
      );

      return rows
          .map((row) => PendingBalanceCustomerEntity(
                customerName: row['customer_name'] as String,
                invoiceNumber: row['invoice_number'] as String,
                total: (row['total'] as num?)?.toDouble() ?? 0,
                paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
                saleDate: DateTimeHelpers.fromSql(row['sale_date'] as String),
              ))
          .toList(growable: false);
    }, operation: 'get_pending_balance_details');
  }

  Future<List<BrandStockEntity>> getBrandStock() {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        pm.brand,
        COUNT(DISTINCT pm.id) AS model_count,
        COUNT(*) AS stock_count
      FROM ${TableNames.serializedStock} ss
      JOIN ${TableNames.productModels} pm ON pm.id =ss.product_model_id
      WHERE pm.is_active = 1 AND ss.stock_status = 'in_stock'
        AND pm.brand IS NOT NULL AND pm.brand != ''
      GROUP BY pm.brand
      ORDER BY stock_count DESC
      ''',
    ).then((rows) {
      if (rows.isEmpty) {
        return <BrandStockEntity>[];
      }
      return rows
          .map(
            (row) => BrandStockEntity(
              brandName: row['brand'] as String,
              brandLogo: '',
              modelCount: (row['model_count'] as num?)?.toInt() ?? 0,
              stockCount: (row['stock_count'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false);
    }).catchError((error) {
      return <BrandStockEntity>[];
    });
  }

  Future<List<PendingReturnEntity>> getPendingReturns() {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        sr.sale_id,
        s.invoice_number,
        sr.created_at AS return_date,
        sr.return_amount
      FROM ${TableNames.saleReturns} sr
      JOIN ${TableNames.sales} s ON s.id = sr.sale_id
      WHERE sr.return_status = 'pending'
      ORDER BY sr.created_at DESC
      LIMIT 5
      ''',
    ).then((rows) => rows
        .map(
          (row) => PendingReturnEntity(
            saleId: (row['sale_id'] as String?) ?? '',
            invoiceNumber: row['invoice_number'] as String,
            returnDate: DateTimeHelpers.fromSql(
              row['return_date'] as String,
            ),
            returnAmount: (row['return_amount'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false));
  }

  Future<List<ModelImeiStockEntity>> getModelImeiStock(String brandName) {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        pm.id AS model_id,
        pm.name AS model_name,
        pm.brand,
        ss.id AS serialized_stock_id,
        ss.imei1 AS imei,
        ss.imei2,
        ss.serial_number,
        ss.cost_price,
        ss.selling_price AS sale_price,
        ss.stock_status
      FROM ${TableNames.serializedStock} ss
      JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
      WHERE pm.is_active = 1
        AND ss.stock_status = 'in_stock'
        AND pm.brand = ?
      ORDER BY pm.name ASC, ss.imei1 ASC
      ''',
      <Object?>[brandName],
    ).then((rows) {
      if (rows.isEmpty) {
        return <ModelImeiStockEntity>[];
      }

      final Map<String, ModelImeiStockEntity> modelMap = {};

      for (final row in rows) {
        final modelId = row['model_id'] as String;
        final modelName = row['model_name'] as String;
        final brand = row['brand'] as String;

        if (!modelMap.containsKey(modelId)) {
          modelMap[modelId] = ModelImeiStockEntity(
            modelId: modelId,
            modelName: modelName,
            brandName: brand,
            quantity: 0,
            imeis: <ImeiStockItemEntity>[],
          );
        }

        modelMap[modelId]!.imeis.add(ImeiStockItemEntity(
              serializedStockId: (row['serialized_stock_id'] as String?) ?? '',
              imei: (row['imei'] as String?) ?? '',
              imei2: row['imei2'] as String?,
              serialNumber: row['serial_number'] as String?,
              costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
              salePrice: (row['sale_price'] as num?)?.toDouble() ?? 0,
              stockStatus: (row['stock_status'] as String?) ?? 'in_stock',
            ));

        modelMap[modelId]!.quantity = modelMap[modelId]!.imeis.length;
      }

      return modelMap.values.toList(growable: false);
    }).catchError((error) {
      return <ModelImeiStockEntity>[];
    });
  }

  /// Fetches all in-stock serialized items across every brand, grouped as
  /// `{ brandName: [ModelImeiStockEntity, ...] }`, sorted brand → model → IMEI.
  Future<Map<String, List<ModelImeiStockEntity>>> getAllModelImeiStock() {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        pm.brand,
        pm.id AS model_id,
        pm.name AS model_name,
        ss.id AS serialized_stock_id,
        ss.imei1 AS imei,
        ss.imei2,
        ss.serial_number,
        ss.cost_price,
        ss.selling_price AS sale_price,
        ss.stock_status
      FROM ${TableNames.serializedStock} ss
      JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
      WHERE pm.is_active = 1
        AND ss.stock_status = 'in_stock'
        AND pm.brand IS NOT NULL AND pm.brand != ''
      ORDER BY pm.brand ASC COLLATE NOCASE,
               pm.name  ASC COLLATE NOCASE,
               ss.imei1 ASC
      ''',
    ).then((rows) {
      if (rows.isEmpty) return <String, List<ModelImeiStockEntity>>{};

      final brandMap = <String, List<ModelImeiStockEntity>>{};
      final modelMap = <String, ModelImeiStockEntity>{};

      for (final row in rows) {
        final brand = row['brand'] as String;
        final modelId = row['model_id'] as String;

        if (!brandMap.containsKey(brand)) {
          brandMap[brand] = <ModelImeiStockEntity>[];
        }

        if (!modelMap.containsKey(modelId)) {
          final model = ModelImeiStockEntity(
            modelId: modelId,
            modelName: row['model_name'] as String,
            brandName: brand,
            quantity: 0,
            imeis: <ImeiStockItemEntity>[],
          );
          modelMap[modelId] = model;
          brandMap[brand]!.add(model);
        }

        modelMap[modelId]!.imeis.add(ImeiStockItemEntity(
          serializedStockId: (row['serialized_stock_id'] as String?) ?? '',
          imei: (row['imei'] as String?) ?? '',
          imei2: row['imei2'] as String?,
          serialNumber: row['serial_number'] as String?,
          costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
          salePrice: (row['sale_price'] as num?)?.toDouble() ?? 0,
          stockStatus: (row['stock_status'] as String?) ?? 'in_stock',
        ));
        modelMap[modelId]!.quantity = modelMap[modelId]!.imeis.length;
      }

      return brandMap;
    }).catchError((_) => <String, List<ModelImeiStockEntity>>{});
  }

  Future<List<DealerStockBreakdownEntity>> getDealerStockBreakdown() {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        COALESCE(d.name, 'Unknown Dealer') AS dealer_name,
        SUM(
          CASE
            WHEN di.imei_list IS NULL OR di.imei_list = '' THEN 0
            ELSE length(di.imei_list) - length(replace(di.imei_list, ',', '')) + 1
          END
        ) AS phone_count
      FROM ${TableNames.dealerIssues} di
      LEFT JOIN ${TableNames.dealers} d ON d.id = di.dealer_id AND d.is_active = 1
      WHERE di.return_status = 0 AND di.sold_status = 0
      GROUP BY di.dealer_id, d.name
      ORDER BY phone_count DESC
      ''',
    ).then(
      (rows) => rows
          .map((r) => DealerStockBreakdownEntity(
                dealerName: r['dealer_name'] as String,
                count: (r['phone_count'] as num?)?.toInt() ?? 0,
              ))
          .toList(growable: false),
    ).catchError((_) => <DealerStockBreakdownEntity>[]);
  }

  /// UTC [start, end) bounds for a dashboard range, derived from the shop's
  /// local calendar (same convention as the "today" KPIs).
  ({DateTime start, DateTime end}) _rangeBounds(DashboardRange range) {
    final localNow = _nowProvider().toLocal();
    final todayStart = DateTime(localNow.year, localNow.month, localNow.day);
    final end = todayStart.add(const Duration(days: 1)).toUtc();
    switch (range) {
      case DashboardRange.today:
        return (start: todayStart.toUtc(), end: end);
      case DashboardRange.week:
        return (
          start: todayStart.subtract(const Duration(days: 6)).toUtc(),
          end: end,
        );
      case DashboardRange.month:
        return (
          start: DateTime(localNow.year, localNow.month, 1).toUtc(),
          end: end,
        );
    }
  }

  /// Sales / profit / units KPIs for the selected range. Uses the same
  /// net-of-returns convention as the today KPIs in [getDashboardKpis].
  Future<Result<RangeSalesKpisEntity>> getRangeSalesKpis(
    DashboardRange range,
  ) {
    return guard<RangeSalesKpisEntity>(() async {
      final bounds = _rangeBounds(range);
      final params = <Object?>[
        DateTimeHelpers.toSql(bounds.start),
        DateTimeHelpers.toSql(bounds.end),
        DateTimeHelpers.toSql(bounds.start),
        DateTimeHelpers.toSql(bounds.end),
      ];

      final salesRows = await QueryDiagnostics.trace(
        label: 'dashboard.range_sales',
        action: () => _appDatabase.database.rawQuery(
          '''
        WITH sale_return_totals AS (
          SELECT
            sale_id,
            COALESCE(SUM(return_amount), 0) AS returned_total
          FROM ${TableNames.saleReturns}
          GROUP BY sale_id
        ),
        return_events AS (
          SELECT
            COALESCE(SUM(return_amount), 0) AS returned_in_range
          FROM ${TableNames.saleReturns}
          WHERE created_at >= ? AND created_at < ?
        )
        SELECT
          COALESCE(SUM(s.total + COALESCE(srt.returned_total, 0)), 0)
            - COALESCE((SELECT returned_in_range FROM return_events), 0)
            AS range_sales
        FROM ${TableNames.sales} s
        LEFT JOIN sale_return_totals srt ON srt.sale_id = s.id
        WHERE s.sale_date >= ? AND s.sale_date < ?
          AND s.status = 'posted'
        ''',
          params,
        ),
      );

      final itemRows = await QueryDiagnostics.trace(
        label: 'dashboard.range_item_aggregates',
        action: () => _appDatabase.database.rawQuery(
          '''
        WITH return_events AS (
          SELECT
            COALESCE(SUM(sr.return_amount), 0) AS returned_revenue,
            COALESCE(SUM(sr.cost_price * sr.return_qty), 0) AS returned_cost
          FROM ${TableNames.saleReturns} sr
          WHERE sr.created_at >= ? AND sr.created_at < ?
        )
        SELECT
          COALESCE(SUM(CASE WHEN pm.has_imei = 1 THEN 1 ELSE 0 END), 0) AS phones_sold,
          COALESCE(SUM(CASE WHEN pm.has_imei = 0 THEN si.quantity ELSE 0 END), 0) AS accessories_sold,
          COALESCE(SUM(
            (si.line_total
              - COALESCE(s.discount * si.line_total / NULLIF(s.subtotal, 0), 0))
            - (si.cost_price * si.quantity)
          ), 0)
            - COALESCE((SELECT returned_revenue FROM return_events), 0)
            + COALESCE((SELECT returned_cost FROM return_events), 0)
            AS range_profit
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.sale_date >= ? AND s.sale_date < ?
          AND s.status = 'posted'
        ''',
          params,
        ),
      );

      final sales = salesRows.first;
      final items = itemRows.first;
      return RangeSalesKpisEntity(
        sales: _asDouble(sales['range_sales']),
        profit: _asDouble(items['range_profit']),
        phonesSold: _asInt(items['phones_sold']),
        accessoriesSold: _asInt(items['accessories_sold']),
      );
    }, operation: 'get_range_sales_kpis');
  }

  /// Net sales per local calendar day for the trailing [days] days
  /// (oldest first, today last). Days without sales are returned as 0 so the
  /// chart always has a fixed number of bars.
  Future<Result<List<DailySalesPointEntity>>> getDailySalesTotals(
      {int days = 7}) {
    return guard<List<DailySalesPointEntity>>(() async {
      final localNow = _nowProvider().toLocal();
      final todayStart = DateTime(localNow.year, localNow.month, localNow.day);
      final windowStart = todayStart.subtract(Duration(days: days - 1));
      final startSql = DateTimeHelpers.toSql(windowStart.toUtc());

      final saleRows = await QueryDiagnostics.trace(
        label: 'dashboard.daily_sales_window',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT
          s.sale_date,
          s.total + COALESCE(srt.returned_total, 0) AS gross_total
        FROM ${TableNames.sales} s
        LEFT JOIN (
          SELECT sale_id, COALESCE(SUM(return_amount), 0) AS returned_total
          FROM ${TableNames.saleReturns}
          GROUP BY sale_id
        ) srt ON srt.sale_id = s.id
        WHERE s.status = 'posted' AND s.sale_date >= ?
        ''',
          <Object?>[startSql],
        ),
      );

      final returnRows = await QueryDiagnostics.trace(
        label: 'dashboard.daily_returns_window',
        action: () => _appDatabase.database.rawQuery(
          '''
        SELECT created_at, return_amount
        FROM ${TableNames.saleReturns}
        WHERE created_at >= ?
        ''',
          <Object?>[startSql],
        ),
      );

      final totals = List<double>.filled(days, 0);
      int? bucketFor(String sqlDate) {
        final local = DateTimeHelpers.fromSql(sqlDate).toLocal();
        final day = DateTime(local.year, local.month, local.day);
        final index = day.difference(windowStart).inDays;
        if (index < 0 || index >= days) return null;
        return index;
      }

      for (final row in saleRows) {
        final index = bucketFor(row['sale_date'] as String);
        if (index != null) {
          totals[index] += _asDouble(row['gross_total']);
        }
      }
      for (final row in returnRows) {
        final index = bucketFor(row['created_at'] as String);
        if (index != null) {
          totals[index] -= _asDouble(row['return_amount']);
        }
      }

      return List<DailySalesPointEntity>.generate(
        days,
        (i) => DailySalesPointEntity(
          day: windowStart.add(Duration(days: i)),
          total: totals[i],
        ),
        growable: false,
      );
    }, operation: 'get_daily_sales_totals');
  }

  /// Mixed recent-activity feed: posted sales, posted purchases, repair jobs
  /// and customer (udhaar) payments merged newest-first.
  Future<Result<List<DashboardTransactionEntity>>> getRecentTransactions(
      {int limit = 8}) {
    return guard<List<DashboardTransactionEntity>>(() async {
      final saleRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          s.id AS sale_id,
          s.invoice_number,
          s.sale_date AS event_date,
          COALESCE(c.name, 'Walk-in Customer') AS party,
          s.total
        FROM ${TableNames.sales} s
        LEFT JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE s.status = 'posted'
        ORDER BY s.sale_date DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      final purchaseRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          p.invoice_number,
          p.purchase_date AS event_date,
          COALESCE(sp.name, 'Supplier') AS party,
          p.total
        FROM ${TableNames.purchases} p
        LEFT JOIN ${TableNames.suppliers} sp ON sp.id = p.supplier_id
        WHERE p.status = 'posted'
        ORDER BY p.purchase_date DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      final repairRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          phone_model,
          created_at AS event_date,
          COALESCE(final_cost, estimated_cost, 0) AS amount
        FROM ${TableNames.repairJobs}
        WHERE is_deleted = 0 AND status != 'cancelled'
        ORDER BY created_at DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      final paymentRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          cpt.amount,
          cpt.created_at AS event_date,
          COALESCE(c.name, 'Customer') AS party
        FROM ${TableNames.customerPaymentTransactions} cpt
        LEFT JOIN ${TableNames.customers} c ON c.id = cpt.customer_id
        ORDER BY cpt.created_at DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );

      final feed = <DashboardTransactionEntity>[
        for (final row in saleRows)
          DashboardTransactionEntity(
            type: DashboardTransactionType.sale,
            title: 'Sale — ${row['party'] as String}',
            reference: row['invoice_number'] as String,
            date: DateTimeHelpers.fromSql(row['event_date'] as String),
            amount: _asDouble(row['total']),
            saleId: row['sale_id']?.toString(),
          ),
        for (final row in purchaseRows)
          DashboardTransactionEntity(
            type: DashboardTransactionType.purchase,
            title: 'Purchase — ${row['party'] as String}',
            reference: (row['invoice_number'] as String?) ?? '',
            date: DateTimeHelpers.fromSql(row['event_date'] as String),
            amount: _asDouble(row['total']),
          ),
        for (final row in repairRows)
          DashboardTransactionEntity(
            type: DashboardTransactionType.repair,
            title: 'Repair — ${row['phone_model'] as String}',
            reference: 'Repair job',
            date: DateTimeHelpers.fromSql(row['event_date'] as String),
            amount: _asDouble(row['amount']),
          ),
        for (final row in paymentRows)
          DashboardTransactionEntity(
            type: DashboardTransactionType.customerPayment,
            title: 'Payment received — ${row['party'] as String}',
            reference: 'Ledger',
            date: DateTimeHelpers.fromSql(row['event_date'] as String),
            amount: _asDouble(row['amount']),
          ),
      ]..sort((a, b) => b.date.compareTo(a.date));

      return feed.take(limit).toList(growable: false);
    }, operation: 'get_recent_transactions');
  }

  /// Brand stock with per-brand worth and low-stock counts, for the
  /// dashboard's Brand Stock table view. Same row source as [getBrandStock]
  /// (in-stock serialized phones), enriched with cost worth and the number of
  /// this brand's accessory items at/below their minimum quantity.
  Future<List<BrandStockEntity>> getBrandStockDetails() {
    return _appDatabase.database.rawQuery(
      '''
      SELECT
        pm.brand,
        COUNT(DISTINCT pm.id) AS model_count,
        COUNT(*) AS stock_count,
        COALESCE(SUM(
          COALESCE(NULLIF(ss.cost_price, 0), pm.purchase_price, 0)
        ), 0) AS stock_worth
      FROM ${TableNames.serializedStock} ss
      JOIN ${TableNames.productModels} pm ON pm.id = ss.product_model_id
      WHERE pm.is_active = 1 AND ss.stock_status = 'in_stock'
        AND pm.brand IS NOT NULL AND pm.brand != ''
      GROUP BY pm.brand
      ORDER BY stock_count DESC
      ''',
    ).then((rows) async {
      if (rows.isEmpty) {
        return <BrandStockEntity>[];
      }

      final lowRows = await _appDatabase.database.rawQuery(
        '''
        SELECT pm.brand, COUNT(*) AS low_count
        FROM ${TableNames.inventoryStock} ist
        JOIN ${TableNames.productModels} pm ON pm.id = ist.product_model_id
        WHERE pm.is_active = 1 AND pm.has_imei = 0
          AND ist.quantity <= ist.min_quantity
          AND pm.brand IS NOT NULL AND pm.brand != ''
        GROUP BY pm.brand
        ''',
      );
      final lowByBrand = <String, int>{
        for (final row in lowRows)
          row['brand'] as String: _asInt(row['low_count']),
      };

      return rows
          .map(
            (row) => BrandStockEntity(
              brandName: row['brand'] as String,
              brandLogo: '',
              modelCount: _asInt(row['model_count']),
              stockCount: _asInt(row['stock_count']),
              stockWorth: _asDouble(row['stock_worth']),
              lowStockCount: lowByBrand[row['brand'] as String] ?? 0,
            ),
          )
          .toList(growable: false);
    }).catchError((error) {
      return <BrandStockEntity>[];
    });
  }

  /// Month-to-date top performers plus today's sale/purchase counts for the
  /// navigation sidebar. All queries are best-effort reads — a missing
  /// leader simply yields null.
  Future<Result<SidebarInsightsEntity>> getSidebarInsights() {
    return guard<SidebarInsightsEntity>(() async {
      final month = _rangeBounds(DashboardRange.month);
      final today = _rangeBounds(DashboardRange.today);
      final monthParams = <Object?>[
        DateTimeHelpers.toSql(month.start),
        DateTimeHelpers.toSql(month.end),
      ];
      final todayParams = <Object?>[
        DateTimeHelpers.toSql(today.start),
        DateTimeHelpers.toSql(today.end),
      ];

      Future<String?> topLabel(String sql) async {
        final rows = await _appDatabase.database.rawQuery(sql, monthParams);
        if (rows.isEmpty) return null;
        final value = rows.first['label'] as String?;
        return (value == null || value.isEmpty) ? null : value;
      }

      final topBrand = await topLabel('''
        SELECT pm.brand AS label
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.status = 'posted' AND s.sale_date >= ? AND s.sale_date < ?
          AND pm.brand IS NOT NULL AND pm.brand != ''
        GROUP BY pm.brand
        ORDER BY SUM(si.quantity) DESC
        LIMIT 1
        ''');

      final topModel = await topLabel('''
        SELECT pm.name AS label
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.status = 'posted' AND s.sale_date >= ? AND s.sale_date < ?
          AND pm.has_imei = 1
        GROUP BY pm.name
        ORDER BY SUM(si.quantity) DESC
        LIMIT 1
        ''');

      final topCustomer = await topLabel('''
        SELECT c.name AS label
        FROM ${TableNames.sales} s
        JOIN ${TableNames.customers} c ON c.id = s.customer_id
        WHERE s.status = 'posted' AND s.sale_date >= ? AND s.sale_date < ?
        GROUP BY c.name
        ORDER BY SUM(s.total) DESC
        LIMIT 1
        ''');

      final topAccessory = await topLabel('''
        SELECT pm.name AS label
        FROM ${TableNames.saleItems} si
        JOIN ${TableNames.sales} s ON s.id = si.sale_id
        JOIN ${TableNames.productModels} pm ON pm.id = si.product_model_id
        WHERE s.status = 'posted' AND s.sale_date >= ? AND s.sale_date < ?
          AND pm.has_imei = 0
        GROUP BY pm.name
        ORDER BY SUM(si.quantity) DESC
        LIMIT 1
        ''');

      final salesCountRows = await _appDatabase.database.rawQuery(
        '''
        SELECT COALESCE(COUNT(*), 0) AS cnt
        FROM ${TableNames.sales}
        WHERE status = 'posted' AND sale_date >= ? AND sale_date < ?
        ''',
        todayParams,
      );

      final purchaseCountRows = await _appDatabase.database.rawQuery(
        '''
        SELECT COALESCE(COUNT(*), 0) AS cnt
        FROM ${TableNames.purchases}
        WHERE status = 'posted' AND purchase_date >= ? AND purchase_date < ?
        ''',
        todayParams,
      );

      return SidebarInsightsEntity(
        topSellingBrand: topBrand,
        topSellingModel: topModel,
        topCustomer: topCustomer,
        topAccessory: topAccessory,
        todaySalesCount: _asInt(salesCountRows.first['cnt']),
        todayPurchasesCount: _asInt(purchaseCountRows.first['cnt']),
      );
    }, operation: 'get_sidebar_insights');
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
