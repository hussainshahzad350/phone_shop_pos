import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_balance_summary_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_direction.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_event_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_query.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/repositories/supplier_ledger_repository.dart';

class SqliteSupplierLedgerRepository
    with BaseRepositoryGuard
    implements SupplierLedgerRepository {
  SqliteSupplierLedgerRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<void>> appendEvent(
    SupplierLedgerEventEntity event, {
    DatabaseExecutor? executor,
  }) {
    return guard<void>(() async {
      final db = executor ?? _appDatabase.database;
      await db.insert(TableNames.supplierLedger, <String, Object?>{
        'id': event.id,
        'party_id': event.partyId,
        'transaction_id': event.transactionId,
        'ledger_type': event.ledgerType,
        'amount': event.amount,
        'direction': event.direction.value,
        'note': event.note,
        'created_at': DateTimeHelpers.toSql(event.createdAt),
        'created_by': event.createdBy,
        'is_reversal': event.isReversal ? 1 : 0,
        'reversal_of': event.reversalOf,
        'payment_method': event.paymentMethod,
      });
    }, operation: 'append_supplier_ledger_event');
  }

  @override
  Future<Result<void>> appendReversalEvent({
    required String reversalEventId,
    required String originalEventId,
    required String partyId,
    required String transactionId,
    required String ledgerType,
    required double amount,
    required String direction,
    required DateTime createdAt,
    String? createdBy,
    String? note,
    String? paymentMethod,
    DatabaseExecutor? executor,
  }) {
    return guard<void>(() async {
      final db = executor ?? _appDatabase.database;
      final existing = await db.query(
        TableNames.supplierLedger,
        columns: <String>['id', 'is_reversal'],
        where: 'id = ?',
        whereArgs: <Object?>[originalEventId],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('Original supplier ledger event not found.');
      }
      if (((existing.first['is_reversal'] as num?)?.toInt() ?? 0) == 1) {
        throw StateError('Reversal of reversal is not allowed.');
      }
      await db.insert(TableNames.supplierLedger, <String, Object?>{
        'id': reversalEventId,
        'party_id': partyId,
        'transaction_id': transactionId,
        'ledger_type': ledgerType,
        'amount': amount,
        'direction': direction,
        'note': note,
        'created_at': DateTimeHelpers.toSql(createdAt),
        'created_by': createdBy,
        'is_reversal': 1,
        'reversal_of': originalEventId,
        'payment_method': paymentMethod,
      });
    }, operation: 'append_supplier_ledger_reversal');
  }

  @override
  Future<Result<List<LedgerTimelineRowEntity>>> fetchTimeline(
    LedgerTimelineQuery query,
  ) {
    return guard<List<LedgerTimelineRowEntity>>(() async {
      final where = <String>['1 = 1'];
      final args = <Object?>[];

      if (query.partyId != null && query.partyId!.trim().isNotEmpty) {
        where.add('sl.party_id = ?');
        args.add(query.partyId!.trim());
      }
      if (query.ledgerType != null && query.ledgerType!.trim().isNotEmpty) {
        where.add('sl.ledger_type = ?');
        args.add(query.ledgerType!.trim());
      }
      if (!query.includePaymentHistory) {
        where.add('sl.ledger_type NOT LIKE ?');
        args.add('%payment%');
      }
      if (query.startDate != null) {
        final startUtc = DateTime.utc(
          query.startDate!.year,
          query.startDate!.month,
          query.startDate!.day,
        );
        where.add('sl.created_at >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }
      if (query.endDate != null) {
        final endUtc = DateTime.utc(
          query.endDate!.year,
          query.endDate!.month,
          query.endDate!.day,
        ).add(const Duration(days: 1));
        where.add('sl.created_at < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }
      if (query.outstandingOnly) {
        where.add('EXISTS (
          SELECT 1 FROM ${TableNames.supplierLedger} b
          WHERE b.party_id = sl.party_id
          GROUP BY b.party_id
          HAVING ABS(COALESCE(SUM(CASE WHEN b.direction = \'credit\' THEN b.amount ELSE 0 END), 0)
                - COALESCE(SUM(CASE WHEN b.direction = \'debit\' THEN b.amount ELSE 0 END), 0)) > 0.009
        )');
      }

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          sl.id,
          sl.party_id,
          COALESCE(s.name, 'Unknown Supplier') AS party_name,
          sl.transaction_id,
          sl.ledger_type,
          sl.amount,
          sl.direction,
          sl.note,
          sl.created_at,
          sl.is_reversal,
          sl.reversal_of,
          sl.payment_method
        FROM ${TableNames.supplierLedger} sl
        LEFT JOIN ${TableNames.suppliers} s ON s.id = sl.party_id
        WHERE ${where.join(' AND ')}
        ORDER BY sl.created_at ASC, sl.id ASC
        LIMIT ? OFFSET ?
        ''',
        <Object?>[...args, query.limit, query.offset],
      );

      var runningBalance = 0.0;
      return rows.map((row) {
        final direction = LedgerDirection.fromValue(row['direction'] as String);
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        runningBalance +=
            direction == LedgerDirection.credit ? amount : -amount;
        return LedgerTimelineRowEntity(
          id: row['id'] as String,
          partyId: row['party_id'] as String,
          partyName: row['party_name'] as String? ?? 'Unknown Supplier',
          transactionId: row['transaction_id'] as String,
          ledgerType: row['ledger_type'] as String,
          amount: amount,
          direction: direction,
          createdAt: DateTimeHelpers.fromSql(row['created_at'] as String),
          runningBalance: runningBalance,
          note: row['note'] as String?,
          isReversal: ((row['is_reversal'] as num?)?.toInt() ?? 0) == 1,
          reversalOf: row['reversal_of'] as String?,
          paymentMethod: row['payment_method'] as String?,
          sourceLabel: row['transaction_id'] as String,
        );
      }).toList(growable: false);
    }, operation: 'fetch_supplier_ledger_timeline');
  }

  @override
  Future<Result<LedgerBalanceSummaryEntity>> computeBalances({
    required String supplierId,
  }) {
    return guard<LedgerBalanceSummaryEntity>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN direction = 'debit' THEN amount ELSE 0 END), 0) AS receivable,
          COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0) AS payable
        FROM ${TableNames.supplierLedger}
        WHERE party_id = ?
        ''',
        <Object?>[supplierId],
      );
      final row = rows.first;
      final receivable = (row['receivable'] as num?)?.toDouble() ?? 0;
      final payable = (row['payable'] as num?)?.toDouble() ?? 0;
      return LedgerBalanceSummaryEntity(
        receivable: receivable,
        payable: payable,
        net: payable - receivable,
      );
    }, operation: 'compute_supplier_ledger_balance');
  }

  @override
  Future<Result<List<PartySummaryCardEntity>>> fetchProfileSummary({
    String? supplierId,
    bool outstandingOnly = false,
  }) {
    return guard<List<PartySummaryCardEntity>>(() async {
      final where = <String>['1 = 1'];
      final args = <Object?>[];
      if (supplierId != null && supplierId.trim().isNotEmpty) {
        where.add('sl.party_id = ?');
        args.add(supplierId.trim());
      }

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          sl.party_id,
          COALESCE(s.name, 'Unknown Supplier') AS party_name,
          COALESCE(SUM(CASE WHEN sl.direction = 'debit' THEN sl.amount ELSE 0 END), 0) AS receivable,
          COALESCE(SUM(CASE WHEN sl.direction = 'credit' THEN sl.amount ELSE 0 END), 0) AS payable,
          MAX(sl.created_at) AS last_activity
        FROM ${TableNames.supplierLedger} sl
        LEFT JOIN ${TableNames.suppliers} s ON s.id = sl.party_id
        WHERE ${where.join(' AND ')}
        GROUP BY sl.party_id
        ORDER BY ABS(payable - receivable) DESC, party_name COLLATE NOCASE ASC
        ''',
        args,
      );

      final summaries = rows.map((row) {
        final receivable = (row['receivable'] as num?)?.toDouble() ?? 0;
        final payable = (row['payable'] as num?)?.toDouble() ?? 0;
        final net = payable - receivable;
        return PartySummaryCardEntity(
          partyId: row['party_id'] as String,
          partyName: row['party_name'] as String? ?? 'Unknown Supplier',
          totalReceivable: receivable,
          totalPayable: payable,
          netBalance: net,
          outstanding: net.abs(),
          lastActivityAt: row['last_activity'] == null
              ? null
              : DateTimeHelpers.fromSql(row['last_activity'] as String),
        );
      }).where((summary) {
        if (!outstandingOnly) {
          return true;
        }
        return summary.outstanding > 0.009;
      }).toList(growable: false);

      return summaries;
    }, operation: 'fetch_supplier_ledger_summary');
  }
}
