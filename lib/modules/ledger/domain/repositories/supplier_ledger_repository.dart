import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_balance_summary_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_event_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_query.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';

abstract class SupplierLedgerRepository extends BaseRepository {
  Future<Result<void>> appendEvent(
    SupplierLedgerEventEntity event, {
    DatabaseExecutor? executor,
  });

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
  });

  Future<Result<List<LedgerTimelineRowEntity>>> fetchTimeline(
    LedgerTimelineQuery query,
  );

  Future<Result<LedgerBalanceSummaryEntity>> computeBalances({
    required String supplierId,
  });

  Future<Result<List<PartySummaryCardEntity>>> fetchProfileSummary({
    String? supplierId,
    bool outstandingOnly = false,
  });
}
