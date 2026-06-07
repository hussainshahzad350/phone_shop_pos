import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/user_facing_errors.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class CreditCollectionService with BaseRepositoryGuard {
  CreditCollectionService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;

  Future<Result<PaymentCollectionEntity>> collectPayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) {
    return guard<PaymentCollectionEntity>(() async {
      final normalizedMethod = PaymentMethod.normalizeNullable(paymentMethod);
      if (normalizedMethod == null) {
        throw StateError('Payment method must be cash, card, or bank.');
      }
      if (normalizedMethod == PaymentMethod.credit) {
        throw StateError('Payment method must be cash, card, or bank.');
      }
      if (amount <= 0) {
        throw StateError('Payment amount must be greater than zero.');
      }
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final notesError =
          NotesSafety.validate(normalizedNotes, fieldLabel: 'Payment notes');
      if (notesError != null) {
        throw StateError(notesError);
      }

      late PaymentCollectionEntity summary;
      await _appDatabase.runInTransaction<void>((transaction) async {
        final saleRows = await transaction.query(
          TableNames.sales,
          columns: <String>['total', 'paid_amount'],
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
          limit: 1,
        );
        if (saleRows.isEmpty) {
          throw StateError('Sale not found.');
        }

        final total = (saleRows.first['total'] as num?)?.toDouble() ?? 0;
        final paid = (saleRows.first['paid_amount'] as num?)?.toDouble() ?? 0;
        final remaining =
            ((total - paid).clamp(0.0, double.infinity)).toDouble();
        if (remaining <= 0) {
          throw AppError(
            code: 'sale_already_paid',
            message: UserFacingErrors.saleOverpayment(remainingBalance: 0),
          );
        }
        if (amount > remaining + 0.009) {
          throw AppError(
            code: UserFacingErrors.saleOverpaymentCode,
            message: UserFacingErrors.saleOverpayment(
              remainingBalance: remaining,
            ),
          );
        }

        final now = DateTimeHelpers.nowUtc();
        final newPaidAmount = paid + amount;

        await transaction.insert(TableNames.salePayments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'pay'),
          'sale_id': saleId,
          'amount': amount,
          'payment_method': normalizedMethod,
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });

        await transaction.update(
          TableNames.sales,
          <String, Object?>{
            'paid_amount': newPaidAmount,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
        );

        final customerRows = await transaction.query(
          TableNames.sales,
          columns: <String>['customer_id'],
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
          limit: 1,
        );
        final customerId = customerRows.first['customer_id'] as String?;
        if (_ledgerPostingService != null &&
            customerId != null &&
            customerId.trim().isNotEmpty &&
            customerId.toLowerCase() != 'walk_in') {
          final ledgerResult = await _ledgerPostingService.postSalePayment(
            saleId: saleId,
            customerId: customerId.trim(),
            amount: amount,
            paymentMethod: normalizedMethod,
            createdAt: now,
            note: normalizedNotes,
            executor: transaction,
          );
          if (ledgerResult.isFailure) {
            throw StateError(ledgerResult.asFailure!.error.message);
          }
        }

        summary = PaymentCollectionEntity(
          newPaidAmount: newPaidAmount,
          remainingBalance: (total - newPaidAmount).clamp(0, double.infinity),
        );
      });

      return summary;
    }, operation: 'collect_payment');
  }

  Future<Result<void>> receiveCustomerCredit(
    CustomerSettlementRequestPayload payload,
  ) {
    if (_ledgerPostingService == null) {
      return guard<void>(() async {
        throw StateError('Ledger posting service is unavailable.');
      });
    }
    return _ledgerPostingService.receiveCustomerCredit(payload);
  }
}
