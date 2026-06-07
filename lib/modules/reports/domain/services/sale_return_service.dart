import 'dart:math' as math;
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class SaleReturnService with BaseRepositoryGuard {
  SaleReturnService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;

  Future<Result<void>> processReturn({
    required String saleId,
    required SalesInvoiceItemEntity item,
    required int quantity,
    required String reason,
    String? notes,
  }) {
    return guard<void>(() async {
      final trimmedReason = reason.trim();
      if (trimmedReason.isEmpty) {
        throw StateError('Return reason is required.');
      }
      if (quantity <= 0) {
        throw StateError('Return quantity must be greater than zero.');
      }
      if (quantity > item.returnableQty) {
        throw StateError(
            'Return quantity exceeds available returnable quantity.');
      }
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();

      await _appDatabase.runInTransaction<void>((transaction) async {
        // ── Read unit cost snapshot from sale_items ───────────────────────
        final saleItemRows = await transaction.query(
          TableNames.saleItems,
          columns: <String>['cost_price'],
          where: 'id = ?',
          whereArgs: <Object?>[item.saleItemId],
          limit: 1,
        );
        if (saleItemRows.isEmpty) {
          throw StateError('Sale item not found for return.');
        }
        final unitCostPrice =
            (saleItemRows.first['cost_price'] as num?)?.toDouble() ?? 0;

        late double returnAmount;
        String? returnedSerializedId;
        String returnType;

        if (item.hasImei) {
          if (quantity != 1) {
            throw StateError(
                'Serialized item return must be exactly one unit.');
          }
          final serializedId = item.serializedStockId;
          if (serializedId == null || serializedId.isEmpty) {
            throw StateError('Serialized item is missing stock reference.');
          }

          final duplicate = await transaction.query(
            TableNames.saleReturns,
            where: 'sale_item_id = ? AND serialized_stock_id = ?',
            whereArgs: <Object?>[item.saleItemId, serializedId],
            limit: 1,
          );
          if (duplicate.isNotEmpty) {
            throw StateError('This IMEI is already returned.');
          }

          await transaction.update(
            TableNames.serializedStock,
            <String, Object?>{
              'stock_status': 'in_stock',
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'id = ?',
            whereArgs: <Object?>[serializedId],
          );

          returnAmount = item.lineTotal;
          returnedSerializedId = serializedId;
          returnType = 'imei';
        } else {
          await transaction.rawInsert(
            '''
            INSERT OR IGNORE INTO ${TableNames.inventoryStock}
            (id, product_model_id, quantity, min_quantity, unit_cost, unit_price, created_at, updated_at)
            VALUES (?, ?, 0, 0, 0, 0, ?, ?)
            ''',
            <Object?>[
              IdHelpers.newId(prefix: 'stk'),
              item.productModelId,
              DateTimeHelpers.toSql(now),
              DateTimeHelpers.toSql(now),
            ],
          );

          final stockRows = await transaction.query(
            TableNames.inventoryStock,
            columns: <String>['quantity'],
            where: 'product_model_id = ?',
            whereArgs: <Object?>[item.productModelId],
            limit: 1,
          );
          if (stockRows.isEmpty) {
            throw StateError('Inventory row missing for return item.');
          }
          final oldQty = (stockRows.first['quantity'] as num?)?.toInt() ?? 0;
          final newQty = oldQty + quantity;

          await transaction.update(
            TableNames.inventoryStock,
            <String, Object?>{
              'quantity': newQty,
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'product_model_id = ?',
            whereArgs: <Object?>[item.productModelId],
          );

          returnAmount = item.unitPrice * quantity;
          returnedSerializedId = null;
          returnType = 'quantity';
        }

        // ── Insert return audit record ────────────────────────────────────
        final saleRows = await transaction.query(
          TableNames.sales,
          columns: <String>[
            'total',
            'paid_amount',
            'payment_method',
            'customer_id'
          ],
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
          limit: 1,
        );
        if (saleRows.isEmpty) {
          throw StateError('Sale not found for financial adjustment.');
        }
        final currentTotal = (saleRows.first['total'] as num?)?.toDouble() ?? 0;
        final currentPaid =
            (saleRows.first['paid_amount'] as num?)?.toDouble() ?? 0;
        final salePaymentMethod = PaymentMethod.normalizeNullable(
          saleRows.first['payment_method'] as String?,
        );
        final newTotal = (currentTotal - returnAmount).clamp(0.0, currentTotal);
        final newPaid = currentPaid.clamp(0.0, newTotal).toDouble();
        final refundedPaidAmount =
            (currentPaid - newPaid).clamp(0, currentPaid).toDouble();

        final paymentRows = await transaction.rawQuery(
          '''
          SELECT
            COALESCE(SUM(amount), 0) AS total_collected,
            COALESCE(SUM(CASE
              WHEN payment_method = '${PaymentMethod.cash}' THEN amount
              ELSE 0
            END), 0) AS cash_collected
          FROM ${TableNames.salePayments}
          WHERE sale_id = ?
          ''',
          <Object?>[saleId],
        );
        final priorRefundRows = await transaction.rawQuery(
          '''
          SELECT
            COALESCE(SUM(refunded_paid_amount), 0) AS refunded_paid_total,
            COALESCE(SUM(refunded_cash_amount), 0) AS refunded_cash_total
          FROM ${TableNames.saleReturns}
          WHERE sale_id = ?
          ''',
          <Object?>[saleId],
        );
        final totalCollected =
            (paymentRows.first['total_collected'] as num?)?.toDouble() ?? 0;
        final cashCollected =
            (paymentRows.first['cash_collected'] as num?)?.toDouble() ?? 0;
        final refundedPaidSoFar =
            (priorRefundRows.first['refunded_paid_total'] as num?)
                    ?.toDouble() ??
                0;
        final refundedCashSoFar =
            (priorRefundRows.first['refunded_cash_total'] as num?)
                    ?.toDouble() ??
                0;
        // currentPaid = original paid at sale time + later collections
        //               - prior refunded paid amounts, so reversing the known
        // adjustments reconstructs the original paid amount before this return.
        final estimatedOriginalPaidAmount =
            math.max(currentPaid - totalCollected + refundedPaidSoFar, 0);
        // Rebuild the cash still represented by this sale before the new return:
        // original cash paid at sale time + later cash collections - prior cash refunds.
        final cashPaidBeforeReturn = math.max(
          (salePaymentMethod == PaymentMethod.cash
                  ? estimatedOriginalPaidAmount
                  : 0) +
              cashCollected -
              refundedCashSoFar,
          0,
        );
        // A return can only refund cash that is still represented by the sale,
        // so cap the refunded cash portion by the cash still attributable to
        // the invoice before this return.
        final refundedCashAmount = refundedPaidAmount <= 0
            ? 0.0
            : math.min(refundedPaidAmount, cashPaidBeforeReturn);

        await transaction.insert(TableNames.saleReturns, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'ret'),
          'sale_id': saleId,
          'sale_item_id': item.saleItemId,
          'product_model_id': item.productModelId,
          'serialized_stock_id': returnedSerializedId,
          'return_type': returnType,
          'return_qty': quantity,
          'return_amount': returnAmount,
          'cost_price': unitCostPrice,
          'refunded_paid_amount': refundedPaidAmount,
          'refunded_cash_amount': refundedCashAmount,
          'reason': trimmedReason,
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });

        // ── Refund Model: reduce sale total and clamp paid_amount ─────────
        await transaction.update(
          TableNames.sales,
          <String, Object?>{
            'total': newTotal,
            'paid_amount': newPaid,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[saleId],
        );

        final customerId = saleRows.first['customer_id'] as String?;
        if (_ledgerPostingService != null &&
            customerId != null &&
            customerId.trim().isNotEmpty &&
            customerId.toLowerCase() != 'walk_in') {
          final ledgerResult = await _ledgerPostingService.postSaleReturn(
            saleId: saleId,
            customerId: customerId.trim(),
            amount: returnAmount,
            createdAt: now,
            note: trimmedReason,
            executor: transaction,
          );
          if (ledgerResult.isFailure) {
            throw StateError(ledgerResult.asFailure!.error.message);
          }
        }
      });
    }, operation: 'process_sale_return');
  }
}
