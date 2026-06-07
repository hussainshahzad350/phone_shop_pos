import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';

class StockAdjustmentService with BaseRepositoryGuard {
  StockAdjustmentService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  }) : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<Result<int>> applyQuantityStockAdjustment({
    required String productModelId,
    required int delta,
    required String reason,
    String? notes,
  }) {
    return guard<int>(() async {
      if (delta == 0) {
        throw StateError('Adjustment quantity cannot be zero.');
      }
      _validateAdjustmentReason(reason);
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();
      late int newQty;

      await _appDatabase.runInTransaction<void>((transaction) async {
        final rows = await transaction.query(
          TableNames.inventoryStock,
          columns: <String>['quantity'],
          where: 'product_model_id = ?',
          whereArgs: <Object?>[productModelId],
          limit: 1,
        );

        if (rows.isEmpty) {
          if (delta < 0) {
            throw StateError(
                'Cannot decrease stock. Item has no inventory row.');
          }
          await transaction.insert(TableNames.inventoryStock, <String, Object?>{
            'id': IdHelpers.newId(prefix: 'stk'),
            'product_model_id': productModelId,
            'quantity': delta,
            'min_quantity': 0,
            'unit_cost': 0,
            'unit_price': 0,
            'created_at': DateTimeHelpers.toSql(now),
            'updated_at': DateTimeHelpers.toSql(now),
          });
          newQty = delta;
        } else {
          final currentQty = (rows.first['quantity'] as num?)?.toInt() ?? 0;
          final nextQty = currentQty + delta;
          if (nextQty < 0) {
            throw StateError('Stock cannot go below zero.');
          }
          await transaction.update(
            TableNames.inventoryStock,
            <String, Object?>{
              'quantity': nextQty,
              'updated_at': DateTimeHelpers.toSql(now),
            },
            where: 'product_model_id = ?',
            whereArgs: <Object?>[productModelId],
          );
          newQty = nextQty;
        }

        await transaction.insert(TableNames.stockAdjustments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'adj'),
          'product_model_id': productModelId,
          'serialized_stock_id': null,
          'adjustment_type': delta > 0 ? 'increase' : 'decrease',
          'quantity_delta': delta,
          'reason': reason.trim().toLowerCase(),
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });
      });

      return newQty;
    }, operation: 'apply_stock_adjustment');
  }

  Future<Result<void>> writeOffSerializedStock({
    required String serializedStockId,
    required String reason,
    String? notes,
  }) {
    return guard<void>(() async {
      _validateAdjustmentReason(reason);
      final normalizedNotes = NotesSafety.normalizeNullable(notes);
      final now = DateTimeHelpers.nowUtc();

      await _appDatabase.runInTransaction<void>((transaction) async {
        final rows = await transaction.query(
          TableNames.serializedStock,
          columns: <String>['product_model_id', 'stock_status', 'imei1'],
          where: 'id = ?',
          whereArgs: <Object?>[serializedStockId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Serialized stock record not found.');
        }
        final row = rows.first;
        final status = row['stock_status'] as String? ?? '';
        if (status != 'in_stock') {
          throw StateError('Only in-stock IMEIs can be written off.');
        }

        await transaction.update(
          TableNames.serializedStock,
          <String, Object?>{
            'stock_status': 'damaged',
            'updated_at': DateTimeHelpers.toSql(now),
          },
          where: 'id = ?',
          whereArgs: <Object?>[serializedStockId],
        );

        await transaction.insert(TableNames.stockAdjustments, <String, Object?>{
          'id': IdHelpers.newId(prefix: 'adj'),
          'product_model_id': row['product_model_id'] as String,
          'serialized_stock_id': serializedStockId,
          'adjustment_type': 'write_off',
          'quantity_delta': -1,
          'reason': reason.trim().toLowerCase(),
          'notes': normalizedNotes,
          'created_at': DateTimeHelpers.toSql(now),
          'updated_at': DateTimeHelpers.toSql(now),
        });
      });
    }, operation: 'write_off_serialized_stock');
  }

  void _validateAdjustmentReason(String reason) {
    final normalized = reason.trim().toLowerCase();
    if (normalized != 'damage' &&
        normalized != 'theft' &&
        normalized != 'correction') {
      throw StateError('Reason must be damage, theft, or correction.');
    }
  }
}
