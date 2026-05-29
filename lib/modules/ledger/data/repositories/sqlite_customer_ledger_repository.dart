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
import 'package:phone_shop_pos/modules/ledger/domain/repositories/customer_ledger_repository.dart';

class SqliteCustomerLedgerRepository
    with BaseRepositoryGuard
    implements CustomerLedgerRepository {
  SqliteCustomerLedgerRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<void>> appendEvent(
    CustomerLedgerEventEntity event, {
    DatabaseExecutor? executor,
  }) {
    return guard<void>(() async {
      final db = executor ?? _appDatabase.database;
      await db.insert(TableNames.customerLedger, <String, Object?>{
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
    }, operation: 'append_customer_ledger_event');
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
        TableNames.customerLedger,
        columns: <String>['id', 'is_reversal'],
        where: 'id = ?',
        whereArgs: <Object?>[originalEventId],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('Original customer ledger event not found.');
      }
      if (((existing.first['is_reversal'] as num?)?.toInt() ?? 0) == 1) {
        throw StateError('Reversal of reversal is not allowed.');
      }
      await db.insert(TableNames.customerLedger, <String, Object?>{
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
    }, operation: 'append_customer_ledger_reversal');
  }

  @override
  Future<Result<List<LedgerTimelineRowEntity>>> fetchTimeline(
    LedgerTimelineQuery query,
  ) {
    return guard<List<LedgerTimelineRowEntity>>(() async {
      final where = <String>['1 = 1'];
      final args = <Object?>[];

      if (query.partyId != null && query.partyId!.trim().isNotEmpty) {
        where.add('cl.party_id = ?');
        args.add(query.partyId!.trim());
      }
      if (query.ledgerType != null && query.ledgerType!.trim().isNotEmpty) {
        where.add('cl.ledger_type = ?');
        args.add(query.ledgerType!.trim());
      }
      if (!query.includePaymentHistory) {
        where.add('cl.ledger_type NOT LIKE ?');
        args.add('%payment%');
      }
      if (query.startDate != null) {
        final startUtc = DateTime.utc(
          query.startDate!.year,
          query.startDate!.month,
          query.startDate!.day,
        );
        where.add('cl.created_at >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }
      if (query.endDate != null) {
        final endUtc = DateTime.utc(
          query.endDate!.year,
          query.endDate!.month,
          query.endDate!.day,
        ).add(const Duration(days: 1));
        where.add('cl.created_at < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }
      if (query.outstandingOnly) {
        where.add('''
          EXISTS (
            SELECT 1 FROM ${TableNames.customerLedger} b
            WHERE b.party_id = cl.party_id
            GROUP BY b.party_id
            HAVING ABS(
              COALESCE(SUM(CASE WHEN b.direction = 'debit' THEN b.amount ELSE 0 END), 0)
              - COALESCE(SUM(CASE WHEN b.direction = 'credit' THEN b.amount ELSE 0 END), 0)
            ) > 0.009
          )
        ''');
      }

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          cl.id,
          cl.party_id,
          COALESCE(c.name, 'Walk-in Customer') AS party_name,
          cl.transaction_id,
          cl.ledger_type,
          cl.amount,
          cl.direction,
          cl.note,
          cl.created_at,
          cl.is_reversal,
          cl.reversal_of,
          cl.payment_method
        FROM ${TableNames.customerLedger} cl
        LEFT JOIN ${TableNames.customers} c ON c.id = cl.party_id
        WHERE ${where.join(' AND ')}
        ORDER BY cl.created_at ASC, cl.id ASC
        LIMIT ? OFFSET ?
        ''',
        <Object?>[...args, query.limit, query.offset],
      );

      var runningBalance = 0.0;
      return rows.map((row) {
        final direction = LedgerDirection.fromValue(row['direction'] as String);
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        runningBalance += direction == LedgerDirection.debit ? amount : -amount;
        return LedgerTimelineRowEntity(
          id: row['id'] as String,
          partyId: row['party_id'] as String,
          partyName: row['party_name'] as String? ?? 'Walk-in Customer',
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
      }).toList(growable: false)
        ..sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          if (byDate != 0) {
            return byDate;
          }
          return b.id.compareTo(a.id);
        });
    }, operation: 'fetch_customer_ledger_timeline');
  }

  @override
  Future<Result<LedgerBalanceSummaryEntity>> computeBalances({
    required String customerId,
    DatabaseExecutor? executor,
  }) {
    return guard<LedgerBalanceSummaryEntity>(() async {
      final db = executor ?? _appDatabase.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN direction = 'debit' THEN amount ELSE 0 END), 0) AS receivable,
          COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0) AS payable
        FROM ${TableNames.customerLedger}
        WHERE party_id = ?
        ''',
        <Object?>[customerId],
      );
      final row = rows.first;
      final receivable = (row['receivable'] as num?)?.toDouble() ?? 0;
      final payable = (row['payable'] as num?)?.toDouble() ?? 0;
      return LedgerBalanceSummaryEntity(
        receivable: receivable,
        payable: payable,
        net: receivable - payable,
      );
    }, operation: 'compute_customer_ledger_balance');
  }

  @override
  Future<Result<List<PartySummaryCardEntity>>> fetchProfileSummary({
    String? customerId,
    bool outstandingOnly = false,
  }) {
    return guard<List<PartySummaryCardEntity>>(() async {
      final where = <String>['1 = 1'];
      final args = <Object?>[];
      if (customerId != null && customerId.trim().isNotEmpty) {
        where.add('cl.party_id = ?');
        args.add(customerId.trim());
      }

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          cl.party_id,
          COALESCE(c.name, 'Walk-in Customer') AS party_name,
          COALESCE(SUM(CASE WHEN cl.direction = 'debit' THEN cl.amount ELSE 0 END), 0) AS receivable,
          COALESCE(SUM(CASE WHEN cl.direction = 'credit' THEN cl.amount ELSE 0 END), 0) AS payable,
          MAX(cl.created_at) AS last_activity
        FROM ${TableNames.customerLedger} cl
        LEFT JOIN ${TableNames.customers} c ON c.id = cl.party_id
        WHERE ${where.join(' AND ')}
        GROUP BY cl.party_id
        ORDER BY ABS(receivable - payable) DESC, party_name COLLATE NOCASE ASC
        ''',
        args,
      );

      final summaries = rows.map((row) {
        final receivable = (row['receivable'] as num?)?.toDouble() ?? 0;
        final payable = (row['payable'] as num?)?.toDouble() ?? 0;
        final net = receivable - payable;
        return PartySummaryCardEntity(
          partyId: row['party_id'] as String,
          partyName: row['party_name'] as String? ?? 'Walk-in Customer',
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
    }, operation: 'fetch_customer_ledger_summary');
  }
}
