import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_query.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';

class LedgerFacadeService with BaseRepositoryGuard {
  LedgerFacadeService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;
  Future<Result<List<SupplierLedgerRowEntity>>> getSupplierLedger({
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 200,
    int offset = 0,
  }) {
    return guard<List<SupplierLedgerRowEntity>>(() async {
      if (_ledgerPostingService != null) {
        final summaryResult =
            await _ledgerPostingService.fetchSupplierSummary();
        if (summaryResult.isFailure) {
          throw StateError(summaryResult.asFailure!.error.message);
        }
        final purchaseCountRows = await _appDatabase.database.rawQuery(
          '''
          SELECT party_id, COUNT(*) AS purchase_count
          FROM ${TableNames.supplierLedger}
          WHERE ledger_type = 'purchase'
          GROUP BY party_id
          ''',
        );
        final purchaseCountBySupplier = <String, int>{
          for (final row in purchaseCountRows)
            (row['party_id'] as String):
                (row['purchase_count'] as num?)?.toInt() ?? 0,
        };
        return summaryResult.asSuccess!.value
            .map(
              (row) => SupplierLedgerRowEntity(
                supplierName: row.partyName,
                purchaseCount: purchaseCountBySupplier[row.partyId] ?? 0,
                totalPurchases: row.totalPayable,
                totalPaid: row.totalReceivable,
              ),
            )
            .toList(growable: false);
      }
      final whereClauses = <String>['1 = 1'];
      final args = <Object?>[];

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

  Future<Result<List<LedgerTimelineRowEntity>>> fetchCustomerLedgerTimeline({
    String? customerId,
    String? ledgerType,
    DateTime? startDate,
    DateTime? endDate,
    bool outstandingOnly = false,
    bool includePaymentHistory = true,
  }) {
    if (_ledgerPostingService == null) {
      return guard<List<LedgerTimelineRowEntity>>(
          () async => const <LedgerTimelineRowEntity>[]);
    }
    return _ledgerPostingService.fetchCustomerTimeline(
      LedgerTimelineQuery(
        partyId: customerId,
        ledgerType: ledgerType,
        startDate: startDate,
        endDate: endDate,
        outstandingOnly: outstandingOnly,
        includePaymentHistory: includePaymentHistory,
      ),
    );
  }

  Future<Result<List<LedgerTimelineRowEntity>>> fetchSupplierLedgerTimeline({
    String? supplierId,
    String? ledgerType,
    DateTime? startDate,
    DateTime? endDate,
    bool outstandingOnly = false,
    bool includePaymentHistory = true,
  }) {
    if (_ledgerPostingService == null) {
      return guard<List<LedgerTimelineRowEntity>>(
          () async => const <LedgerTimelineRowEntity>[]);
    }
    return _ledgerPostingService.fetchSupplierTimeline(
      LedgerTimelineQuery(
        partyId: supplierId,
        ledgerType: ledgerType,
        startDate: startDate,
        endDate: endDate,
        outstandingOnly: outstandingOnly,
        includePaymentHistory: includePaymentHistory,
      ),
    );
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchCustomerLedgerSummary({
    String? customerId,
    bool outstandingOnly = false,
  }) {
    if (_ledgerPostingService == null) {
      return guard<List<PartySummaryCardEntity>>(
          () async => const <PartySummaryCardEntity>[]);
    }
    return _ledgerPostingService.fetchCustomerSummary(
      customerId: customerId,
      outstandingOnly: outstandingOnly,
    );
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchSupplierLedgerSummary({
    String? supplierId,
    bool outstandingOnly = false,
  }) {
    if (_ledgerPostingService == null) {
      return guard<List<PartySummaryCardEntity>>(
          () async => const <PartySummaryCardEntity>[]);
    }
    return _ledgerPostingService.fetchSupplierSummary(
      supplierId: supplierId,
      outstandingOnly: outstandingOnly,
    );
  }
}
