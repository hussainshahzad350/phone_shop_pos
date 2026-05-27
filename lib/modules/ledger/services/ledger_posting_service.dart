import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/customer_ledger_type.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_direction.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_event_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_query.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/supplier_ledger_type.dart';
import 'package:phone_shop_pos/modules/ledger/domain/repositories/customer_ledger_repository.dart';
import 'package:phone_shop_pos/modules/ledger/domain/repositories/supplier_ledger_repository.dart';

class LedgerPostingService with BaseRepositoryGuard {
  LedgerPostingService({
    required AppDatabase appDatabase,
    required CustomerLedgerRepository customerLedgerRepository,
    required SupplierLedgerRepository supplierLedgerRepository,
  })  : _appDatabase = appDatabase,
        _customerLedgerRepository = customerLedgerRepository,
        _supplierLedgerRepository = supplierLedgerRepository;

  final AppDatabase _appDatabase;
  final CustomerLedgerRepository _customerLedgerRepository;
  final SupplierLedgerRepository _supplierLedgerRepository;

  Future<Result<void>> postSaleCreated({
    required String saleId,
    required String customerId,
    required double amount,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendCustomerEvent(
      customerId: customerId,
      transactionId: saleId,
      ledgerType: CustomerLedgerType.sale,
      amount: amount,
      direction: LedgerDirection.debit,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postSalePayment({
    required String saleId,
    required String customerId,
    required double amount,
    required String paymentMethod,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendCustomerEvent(
      customerId: customerId,
      transactionId: saleId,
      ledgerType: CustomerLedgerType.salePayment,
      amount: amount,
      direction: LedgerDirection.credit,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postSaleReturn({
    required String saleId,
    required String customerId,
    required double amount,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendCustomerEvent(
      customerId: customerId,
      transactionId: saleId,
      ledgerType: CustomerLedgerType.saleReturn,
      amount: amount,
      direction: LedgerDirection.credit,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postRepairDue({
    required String repairId,
    required String customerId,
    required double amount,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    if (amount <= 0) {
      return const Success<void>(null);
    }

    Future<Result<void>> postRepairDueReduction({
      required String repairId,
      required String customerId,
      required double amount,
      required DateTime createdAt,
      String? note,
      DatabaseExecutor? executor,
    }) {
      if (amount <= 0) {
        return const Success<void>(null);
      }
      return _appendCustomerEvent(
        customerId: customerId,
        transactionId: repairId,
        ledgerType: CustomerLedgerType.repairDue,
        amount: amount,
        direction: LedgerDirection.credit,
        createdAt: createdAt,
        note: note,
        executor: executor,
      );
    }
    return _appendCustomerEvent(
      customerId: customerId,
      transactionId: repairId,
      ledgerType: CustomerLedgerType.repairDue,
      amount: amount,
      direction: LedgerDirection.debit,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postRepairPayment({
    required String repairId,
    required String customerId,
    required double amount,
    required String paymentMethod,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    if (amount <= 0) {
      return const Success<void>(null);
    }
    return _appendCustomerEvent(
      customerId: customerId,
      transactionId: repairId,
      ledgerType: CustomerLedgerType.repairPayment,
      amount: amount,
      direction: LedgerDirection.credit,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postPurchaseCreated({
    required String purchaseId,
    required String supplierId,
    required double amount,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendSupplierEvent(
      supplierId: supplierId,
      transactionId: purchaseId,
      ledgerType: SupplierLedgerType.purchase,
      amount: amount,
      direction: LedgerDirection.credit,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postSupplierPayment({
    required String transactionId,
    required String supplierId,
    required double amount,
    required String paymentMethod,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendSupplierEvent(
      supplierId: supplierId,
      transactionId: transactionId,
      ledgerType: SupplierLedgerType.purchasePayment,
      amount: amount,
      direction: LedgerDirection.debit,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<void>> postPurchaseReturn({
    required String purchaseId,
    required String supplierId,
    required double amount,
    required DateTime createdAt,
    String? note,
    DatabaseExecutor? executor,
  }) {
    return _appendSupplierEvent(
      supplierId: supplierId,
      transactionId: purchaseId,
      ledgerType: SupplierLedgerType.purchaseReturn,
      amount: amount,
      direction: LedgerDirection.debit,
      createdAt: createdAt,
      note: note,
      executor: executor,
    );
  }

  Future<Result<List<LedgerTimelineRowEntity>>> fetchCustomerTimeline(
    LedgerTimelineQuery query,
  ) {
    return _customerLedgerRepository.fetchTimeline(query);
  }

  Future<Result<List<LedgerTimelineRowEntity>>> fetchSupplierTimeline(
    LedgerTimelineQuery query,
  ) {
    return _supplierLedgerRepository.fetchTimeline(query);
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchCustomerSummary({
    String? customerId,
    bool outstandingOnly = false,
  }) {
    return _customerLedgerRepository.fetchProfileSummary(
      customerId: customerId,
      outstandingOnly: outstandingOnly,
    );
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchSupplierSummary({
    String? supplierId,
    bool outstandingOnly = false,
  }) {
    return _supplierLedgerRepository.fetchProfileSummary(
      supplierId: supplierId,
      outstandingOnly: outstandingOnly,
    );
  }

  Future<Result<void>> receiveCustomerCredit(
    CustomerSettlementRequestPayload payload,
  ) {
    return guard<void>(() async {
      _validateSettlementAmount(payload.amount);
      final normalizedPaymentMethod =
          PaymentMethod.normalizeNullable(payload.paymentMethod);
      if (normalizedPaymentMethod == null) {
        throw StateError('Payment method must be cash, card, or bank.');
      }

      final normalizedNote = NotesSafety.normalizeNullable(payload.note);
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.runInTransaction<void>((transaction) async {
        final summaryResult = await _customerLedgerRepository.computeBalances(
          customerId: payload.customerId,
        );
        if (summaryResult.isFailure) {
          throw summaryResult.asFailure!.error;
        }
        final net = summaryResult.asSuccess!.value.net;
        if (net <= 0.009) {
          throw StateError('Customer has no receivable outstanding balance.');
        }
        if (payload.amount > net + 0.009) {
          throw StateError('Amount exceeds receivable outstanding balance.');
        }

        final settlementId = IdHelpers.newId(prefix: 'cst');
        await transaction.insert(
          TableNames.customerPaymentTransactions,
          <String, Object?>{
            'id': settlementId,
            'customer_id': payload.customerId,
            'amount': payload.amount,
            'payment_method': normalizedPaymentMethod,
            'note': normalizedNote,
            'created_at': DateTimeHelpers.toSql(now),
            'created_by': payload.createdBy,
            'idempotency_key': payload.idempotencyKey,
          },
        );

        final ledgerResult = await postSalePayment(
          saleId: settlementId,
          customerId: payload.customerId,
          amount: payload.amount,
          paymentMethod: normalizedPaymentMethod,
          createdAt: now,
          note: normalizedNote,
          executor: transaction,
        );
        if (ledgerResult.isFailure) {
          throw ledgerResult.asFailure!.error;
        }

        await _appendAuditRecord(
          transaction: transaction,
          action: 'receive_customer_credit',
          actorId: payload.createdBy,
          entityId: payload.customerId,
          details:
              'Amount ${payload.amount} via $normalizedPaymentMethod. ${normalizedNote ?? ''}',
          createdAt: now,
        );
      });
    }, operation: 'receive_customer_credit');
  }

  Future<Result<void>> paySupplierCredit(
    SupplierSettlementRequestPayload payload,
  ) {
    return guard<void>(() async {
      _validateSettlementAmount(payload.amount);
      final normalizedPaymentMethod =
          PaymentMethod.normalizeNullable(payload.paymentMethod);
      if (normalizedPaymentMethod == null) {
        throw StateError('Payment method must be cash, card, or bank.');
      }
      final normalizedNote = NotesSafety.normalizeNullable(payload.note);
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.runInTransaction<void>((transaction) async {
        final summaryResult = await _supplierLedgerRepository.computeBalances(
          supplierId: payload.supplierId,
        );
        if (summaryResult.isFailure) {
          throw summaryResult.asFailure!.error;
        }
        final net = summaryResult.asSuccess!.value.net;
        if (net <= 0.009) {
          throw StateError('Supplier has no payable outstanding balance.');
        }
        if (payload.amount > net + 0.009) {
          throw StateError('Amount exceeds payable outstanding balance.');
        }

        final settlementId = IdHelpers.newId(prefix: 'spt');
        await transaction.insert(
          TableNames.supplierPaymentTransactions,
          <String, Object?>{
            'id': settlementId,
            'supplier_id': payload.supplierId,
            'amount': payload.amount,
            'payment_method': normalizedPaymentMethod,
            'note': normalizedNote,
            'created_at': DateTimeHelpers.toSql(now),
            'created_by': payload.createdBy,
            'idempotency_key': payload.idempotencyKey,
          },
        );

        final ledgerResult = await postSupplierPayment(
          transactionId: settlementId,
          supplierId: payload.supplierId,
          amount: payload.amount,
          paymentMethod: normalizedPaymentMethod,
          createdAt: now,
          note: normalizedNote,
          executor: transaction,
        );
        if (ledgerResult.isFailure) {
          throw ledgerResult.asFailure!.error;
        }

        await _appendAuditRecord(
          transaction: transaction,
          action: 'pay_supplier_credit',
          actorId: payload.createdBy,
          entityId: payload.supplierId,
          details:
              'Amount ${payload.amount} via $normalizedPaymentMethod. ${normalizedNote ?? ''}',
          createdAt: now,
        );
      });
    }, operation: 'pay_supplier_credit');
  }

  Future<Result<void>> _appendCustomerEvent({
    required String customerId,
    required String transactionId,
    required CustomerLedgerType ledgerType,
    required double amount,
    required LedgerDirection direction,
    required DateTime createdAt,
    String? createdBy,
    String? note,
    String? paymentMethod,
    DatabaseExecutor? executor,
  }) {
    return _customerLedgerRepository.appendEvent(
      CustomerLedgerEventEntity(
        id: IdHelpers.newId(prefix: 'clg'),
        partyId: customerId,
        transactionId: transactionId,
        ledgerType: ledgerType.value,
        amount: amount,
        direction: direction,
        createdAt: createdAt,
        createdBy: createdBy,
        isReversal: false,
        reversalOf: null,
        note: note,
        paymentMethod: paymentMethod,
      ),
      executor: executor,
    );
  }

  Future<Result<void>> _appendSupplierEvent({
    required String supplierId,
    required String transactionId,
    required SupplierLedgerType ledgerType,
    required double amount,
    required LedgerDirection direction,
    required DateTime createdAt,
    String? createdBy,
    String? note,
    String? paymentMethod,
    DatabaseExecutor? executor,
  }) {
    return _supplierLedgerRepository.appendEvent(
      SupplierLedgerEventEntity(
        id: IdHelpers.newId(prefix: 'slg'),
        partyId: supplierId,
        transactionId: transactionId,
        ledgerType: ledgerType.value,
        amount: amount,
        direction: direction,
        createdAt: createdAt,
        createdBy: createdBy,
        isReversal: false,
        reversalOf: null,
        note: note,
        paymentMethod: paymentMethod,
      ),
      executor: executor,
    );
  }

  Future<void> _appendAuditRecord({
    required DatabaseExecutor transaction,
    required String action,
    required String entityId,
    required DateTime createdAt,
    String? actorId,
    String? details,
  }) {
    return transaction.insert(
      TableNames.auditLogs,
      <String, Object?>{
        'id': IdHelpers.newId(prefix: 'aud'),
        'action': action,
        'actor_id': actorId,
        'entity_id': entityId,
        'details': details,
        'created_at': DateTimeHelpers.toSql(createdAt),
      },
    );
  }

  void _validateSettlementAmount(double amount) {
    if (amount <= 0) {
      throw StateError('Amount must be greater than zero.');
    }
    if (amount.isNaN || amount.isInfinite) {
      throw StateError('Invalid amount.');
    }
  }
}
