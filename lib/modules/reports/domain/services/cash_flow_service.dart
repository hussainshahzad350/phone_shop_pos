import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class CashFlowService with BaseRepositoryGuard {
  CashFlowService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  }) : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<List<CashLedgerRowEntity>>> getCashLedger({
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 200,
    int offset = 0,
  }) {
    return guard<List<CashLedgerRowEntity>>(() async {
      final salesArgs = <Object?>[];
      final collectionsArgs = <Object?>[PaymentMethod.cash];
      final returnsArgs = <Object?>[];
      final purchasesArgs = <Object?>[];
      final expensesArgs = <Object?>[];
      final customerSettlementArgs = <Object?>[PaymentMethod.cash];
      final supplierSettlementArgs = <Object?>[PaymentMethod.cash];
      final salesWhere = StringBuffer("s.status = 'posted'");
      final collectionsWhere = StringBuffer(
        "sp.payment_method = ? AND EXISTS (SELECT 1 FROM ${TableNames.sales} s WHERE s.id = sp.sale_id AND s.status = 'posted')",
      );
      final returnsWhere = StringBuffer(
        "EXISTS (SELECT 1 FROM ${TableNames.sales} s WHERE s.id = sr.sale_id AND s.status = 'posted')",
      );
      final purchaseReturnsArgs = <Object?>[];
      final purchaseReturnsWhere = StringBuffer('1 = 1');
      final purchasesWhere = StringBuffer(
        "p.status = 'posted' AND (p.payment_method = '${PaymentMethod.cash}' OR p.payment_method IS NULL)",
      );
      final expensesWhere = StringBuffer(
        "e.is_deleted = 0 AND (e.payment_method = '${PaymentMethod.cash}' OR e.payment_method IS NULL)",
      );
      final customerSettlementWhere = StringBuffer('cpt.payment_method = ?');
      final supplierSettlementWhere = StringBuffer('spt.payment_method = ?');

      if (startDate != null) {
        // Local-day boundary → UTC instant, matching the localtime day buckets
        // above so a range filter selects the same rows shown per day.
        final startUtc =
            DateTime(startDate.year, startDate.month, startDate.day).toUtc();
        final startSql = DateTimeHelpers.toSql(startUtc);
        salesWhere.write(' AND s.sale_date >= ?');
        salesArgs.add(startSql);
        collectionsWhere.write(' AND sp.created_at >= ?');
        collectionsArgs.add(startSql);
        returnsWhere.write(' AND sr.created_at >= ?');
        returnsArgs.add(startSql);
        purchaseReturnsWhere.write(' AND pr.created_at >= ?');
        purchaseReturnsArgs.add(startSql);
        purchasesWhere.write(' AND p.purchase_date >= ?');
        purchasesArgs.add(startSql);
        expensesWhere.write(' AND e.expense_date >= ?');
        expensesArgs.add(startSql);
        customerSettlementWhere.write(' AND cpt.created_at >= ?');
        customerSettlementArgs.add(startSql);
        supplierSettlementWhere.write(' AND spt.created_at >= ?');
        supplierSettlementArgs.add(startSql);
      }

      if (endDate != null) {
        final endUtc =
            DateTime(endDate.year, endDate.month, endDate.day + 1).toUtc();
        final endSql = DateTimeHelpers.toSql(endUtc);
        salesWhere.write(' AND s.sale_date < ?');
        salesArgs.add(endSql);
        collectionsWhere.write(' AND sp.created_at < ?');
        collectionsArgs.add(endSql);
        returnsWhere.write(' AND sr.created_at < ?');
        returnsArgs.add(endSql);
        purchaseReturnsWhere.write(' AND pr.created_at < ?');
        purchaseReturnsArgs.add(endSql);
        purchasesWhere.write(' AND p.purchase_date < ?');
        purchasesArgs.add(endSql);
        expensesWhere.write(' AND e.expense_date < ?');
        expensesArgs.add(endSql);
        customerSettlementWhere.write(' AND cpt.created_at < ?');
        customerSettlementArgs.add(endSql);
        supplierSettlementWhere.write(' AND spt.created_at < ?');
        supplierSettlementArgs.add(endSql);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.operations.cash_ledger',
        action: () => _appDatabase.database.rawQuery(
          '''
          WITH payments_by_sale AS (
            SELECT
              sp.sale_id AS sale_id,
              COALESCE(SUM(sp.amount), 0) AS total_collected
            FROM ${TableNames.salePayments} sp
            GROUP BY sp.sale_id
          ),
          refunds_by_sale AS (
            SELECT
              sr.sale_id AS sale_id,
              COALESCE(SUM(sr.refunded_paid_amount), 0) AS refunded_paid_total,
              COALESCE(SUM(sr.refunded_cash_amount), 0) AS refunded_cash_total
            FROM ${TableNames.saleReturns} sr
            GROUP BY sr.sale_id
          ),
          sales_cash AS (
            SELECT
              date(s.sale_date, 'localtime') AS day,
              COALESCE(
                SUM(
                  CASE
                    WHEN s.payment_method = '${PaymentMethod.cash}' THEN MAX(
                      COALESCE(s.paid_amount, 0)
                        - COALESCE(pbs.total_collected, 0)
                        + COALESCE(rbs.refunded_paid_total, 0),
                      0
                    )
                    ELSE 0
                  END
                ),
                0
              ) AS cash_sales_in
            FROM ${TableNames.sales} s
            LEFT JOIN payments_by_sale pbs ON pbs.sale_id = s.id
            LEFT JOIN refunds_by_sale rbs ON rbs.sale_id = s.id
            WHERE ${salesWhere.toString()}
            GROUP BY date(s.sale_date, 'localtime')
          ),
          collections_cash AS (
            SELECT
              date(sp.created_at, 'localtime') AS day,
              COALESCE(SUM(sp.amount), 0) AS cash_collections_in
            FROM ${TableNames.salePayments} sp
            WHERE ${collectionsWhere.toString()}
            GROUP BY date(sp.created_at, 'localtime')
          ),
          refunds_cash AS (
            SELECT
              date(sr.created_at, 'localtime') AS day,
              COALESCE(SUM(sr.refunded_cash_amount), 0) AS cash_refunds_out
            FROM ${TableNames.saleReturns} sr
            WHERE ${returnsWhere.toString()}
            GROUP BY date(sr.created_at, 'localtime')
          ),
          purchase_refunds_in AS (
            SELECT
              date(pr.created_at, 'localtime') AS day,
              COALESCE(SUM(pr.refunded_cash_amount), 0) AS cash_refunds_in
            FROM ${TableNames.purchaseReturns} pr
            WHERE ${purchaseReturnsWhere.toString()}
            GROUP BY date(pr.created_at, 'localtime')
          ),
          purchase_out AS (
            SELECT
              date(p.purchase_date, 'localtime') AS day,
              COALESCE(SUM(p.paid_amount), 0) AS purchase_payments_out
            FROM ${TableNames.purchases} p
            WHERE ${purchasesWhere.toString()}
            GROUP BY date(p.purchase_date, 'localtime')
          ),
          expense_out AS (
            SELECT
              date(e.expense_date, 'localtime') AS day,
              COALESCE(SUM(e.amount), 0) AS expenses_out
            FROM ${TableNames.expenses} e
            WHERE ${expensesWhere.toString()}
            GROUP BY date(e.expense_date, 'localtime')
          ),
          customer_settlement_in AS (
            SELECT
              date(cpt.created_at, 'localtime') AS day,
              COALESCE(SUM(cpt.amount), 0) AS customer_settlement_in
            FROM ${TableNames.customerPaymentTransactions} cpt
            WHERE ${customerSettlementWhere.toString()}
            GROUP BY date(cpt.created_at, 'localtime')
          ),
          supplier_settlement_out AS (
            SELECT
              date(spt.created_at, 'localtime') AS day,
              COALESCE(SUM(spt.amount), 0) AS supplier_settlement_out
            FROM ${TableNames.supplierPaymentTransactions} spt
            WHERE ${supplierSettlementWhere.toString()}
            GROUP BY date(spt.created_at, 'localtime')
          ),
          all_days AS (
            SELECT day FROM sales_cash
            UNION
            SELECT day FROM collections_cash
            UNION
            SELECT day FROM refunds_cash
            UNION
            SELECT day FROM purchase_refunds_in
            UNION
            SELECT day FROM purchase_out
            UNION
            SELECT day FROM expense_out
            UNION
            SELECT day FROM customer_settlement_in
            UNION
            SELECT day FROM supplier_settlement_out
          )
          SELECT
            d.day,
            COALESCE(sc.cash_sales_in, 0) AS cash_sales_in,
            COALESCE(cc.cash_collections_in, 0) + COALESCE(csi.customer_settlement_in, 0) AS cash_collections_in,
            COALESCE(rc.cash_refunds_out, 0) AS cash_refunds_out,
            COALESCE(po.purchase_payments_out, 0) + COALESCE(sso.supplier_settlement_out, 0) AS purchase_payments_out,
            COALESCE(pri.cash_refunds_in, 0) AS purchase_refunds_in,
            COALESCE(eo.expenses_out, 0) AS expenses_out
          FROM all_days d
          LEFT JOIN sales_cash sc ON sc.day = d.day
          LEFT JOIN collections_cash cc ON cc.day = d.day
          LEFT JOIN refunds_cash rc ON rc.day = d.day
          LEFT JOIN purchase_out po ON po.day = d.day
          LEFT JOIN purchase_refunds_in pri ON pri.day = d.day
          LEFT JOIN expense_out eo ON eo.day = d.day
          LEFT JOIN customer_settlement_in csi ON csi.day = d.day
          LEFT JOIN supplier_settlement_out sso ON sso.day = d.day
          ORDER BY d.day DESC
          LIMIT ? OFFSET ?
          ''',
          <Object?>[
            ...salesArgs,
            ...collectionsArgs,
            ...returnsArgs,
            ...purchaseReturnsArgs,
            ...purchasesArgs,
            ...expensesArgs,
            ...customerSettlementArgs,
            ...supplierSettlementArgs,
            limit,
            offset,
          ],
        ),
      );

      return rows.map((row) {
        return CashLedgerRowEntity(
          day: row['day'] as String,
          cashSalesIn: (row['cash_sales_in'] as num?)?.toDouble() ?? 0,
          cashCollectionsIn:
              (row['cash_collections_in'] as num?)?.toDouble() ?? 0,
          cashRefundsOut: (row['cash_refunds_out'] as num?)?.toDouble() ?? 0,
          purchasePaymentsOut:
              (row['purchase_payments_out'] as num?)?.toDouble() ?? 0,
          purchaseRefundsIn:
              (row['purchase_refunds_in'] as num?)?.toDouble() ?? 0,
          expensesOut: (row['expenses_out'] as num?)?.toDouble() ?? 0,
        );
      }).toList(growable: false);
    }, operation: 'cash_ledger');
  }
}
