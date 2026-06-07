import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';

class PurchaseReturnService with BaseRepositoryGuard {
  PurchaseReturnService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;

  Future<Result<void>> processPurchaseReturn({
    required String purchaseId,
    required PurchaseHistoryItemEntity item,
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
        final purchaseItemRows = await transaction.query(
          TableNames.purchaseItems,
          columns: <String>['unit_cost'],
          where: 'id = ?',
          whereArgs: <Object?>[item.purchaseItemId],
          limit: 1,
        );
        if (purchaseItemRows.isEmpty) {
          throw StateError('Purchase item not found for return.');
        }
        final unitCostPrice =
            (purchaseItemRows.first['unit_cost'] as num?)?.toDouble() ?? 0;

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
            TableNames.purchaseReturns,
            where: 'purchase_item_id = ? AND serialized_stock_id = ?',
            whereArgs: <Object?>[item.purchaseItemId, serializedId],
            limit: 1,
          );
          if (duplicate.isNotEmpty) {
            throw StateError('This IMEI is already returned.');
          }

          await transaction.update(
            TableNames.serializedStock,
            <String, Object?>{
              'stock_status': 'returned',
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'id = ?',
            whereArgs: <Object?>[serializedId],
          );

          returnAmount = item.lineTotal;
          returnedSerializedId = serializedId;
          returnType = 'imei';
        } else {
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
          final newQty = oldQty - quantity;
          if (newQty < 0) {
            throw StateError(
                'Cannot return more non-serialized stock than is currently in inventory.');
          }

          await transaction.update(
            TableNames.inventoryStock,
            <String, Object?>{
              'quantity': newQty,
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'product_model_id = ?',
            whereArgs: <Object?>[item.productModelId],
          );

          returnAmount = item.unitCost * quantity;
          returnedSerializedId = null;
          returnType = 'quantity';
        }

        final purchaseRows = await transaction.query(
          TableNames.purchases,
          columns: <String>['total', 'paid_amount', 'supplier_id'],
          where: 'id = ?',
          whereArgs: <Object?>[purchaseId],
          limit: 1,
        );
        if (purchaseRows.isEmpty) {
          throw StateError('Purchase not found for financial adjustment.');
        }
        final currentTotal =
            (purchaseRows.first['total'] as num?)?.toDouble() ?? 0;
        final currentPaid =
            (purchaseRows.first['paid_amount'] as num?)?.toDouble() ?? 0;

        final newTotal = (currentTotal - returnAmount).clamp(0.0, currentTotal);
        final newPaid = currentPaid.clamp(0.0, newTotal).toDouble();
        final refundedPaidAmount =
            (currentPaid - newPaid).clamp(0, currentPaid).toDouble();

        final refundedCashAmount = refundedPaidAmount;

        await transaction.insert(TableNames.purchaseReturns, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'pret'),
          'purchase_id': purchaseId,
          'purchase_item_id': item.purchaseItemId,
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

        await transaction.update(
          TableNames.purchases,
          <String, Object?>{
            'total': newTotal,
            'paid_amount': newPaid,
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[purchaseId],
        );

        final supplierId = purchaseRows.first['supplier_id'] as String?;
        if (_ledgerPostingService != null &&
            supplierId != null &&
            supplierId.trim().isNotEmpty) {
          final ledgerResult = await _ledgerPostingService.postPurchaseReturn(
            purchaseId: purchaseId,
            supplierId: supplierId.trim(),
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
    }, operation: 'process_purchase_return');
  }
}
