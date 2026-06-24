import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/repositories/dealer_issue_repository.dart';

class SqliteDealerIssueRepository implements DealerIssueRepository {
  final AppDatabase _appDatabase;

  SqliteDealerIssueRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  Database get _db => _appDatabase.database;

  @override
  Future<Result<List<DealerIssueEntity>>> getAllIssues() async {
    return await guard(() async {
      final List<Map<String, dynamic>> maps = await _db.query(
        TableNames.dealerIssues,
        orderBy: 'issue_date DESC',
      );
      return maps.map((map) => DealerIssueEntity.fromMap(map)).toList();
    });
  }

  @override
  Future<Result<DealerIssueEntity>> getIssueById(String issueId) async {
    return await guard(() async {
      final List<Map<String, dynamic>> maps = await _db.query(
        TableNames.dealerIssues,
        where: 'issue_id = ?',
        whereArgs: [issueId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw AppError(code: 'not_found', message: 'Issue not found');
      }

      return DealerIssueEntity.fromMap(maps.first);
    });
  }

  @override
  Future<Result<List<DealerIssueEntity>>> getIssuesByDealer(String dealerId) async {
    return await guard(() async {
      final List<Map<String, dynamic>> maps = await _db.query(
        TableNames.dealerIssues,
        where: 'dealer_id = ?',
        whereArgs: [dealerId],
        orderBy: 'issue_date DESC',
      );
      return maps.map((map) => DealerIssueEntity.fromMap(map)).toList();
    });
  }

  @override
  Future<Result<List<DealerIssueEntity>>> getIssuesByStatus(String status) async {
    return await guard(() async {
      final List<Map<String, dynamic>> maps = await _db.query(
        TableNames.dealerIssues,
        where: 'sold_status = ?',
        whereArgs: [status == 'Sold' ? 1 : 0],
        orderBy: 'issue_date DESC',
      );
      return maps.map((map) => DealerIssueEntity.fromMap(map)).toList();
    });
  }

  /// Creates a dealer issue and marks each listed IMEI as 'with_dealer' in
  /// serialized_stock. Fails atomically if any IMEI is not currently 'in_stock'.
  @override
  Future<Result<DealerIssueEntity>> createIssue(DealerIssueEntity issue) async {
    return await guard(() async {
      await _db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();

        for (final imei in issue.imeiList) {
          final rows = await txn.query(
            TableNames.serializedStock,
            columns: ['id'],
            where: "(imei1 = ? OR imei2 = ?) AND stock_status = 'in_stock'",
            whereArgs: [imei, imei],
            limit: 1,
          );
          if (rows.isEmpty) {
            throw AppError(
              code: 'imei_not_available',
              message:
                  'IMEI $imei is not available for issue (not in stock or already issued)',
            );
          }
          await txn.update(
            TableNames.serializedStock,
            {'stock_status': 'with_dealer', 'updated_at': now},
            where: 'imei1 = ? OR imei2 = ?',
            whereArgs: [imei, imei],
          );
        }

        await txn.insert(TableNames.dealerIssues, issue.toMap());
      });

      return issue;
    });
  }

  @override
  Future<Result<bool>> updateIssue(DealerIssueEntity issue) async {
    return await guard(() async {
      final rows = await _db.update(
        TableNames.dealerIssues,
        issue.toMap(),
        where: 'issue_id = ?',
        whereArgs: [issue.issueId],
      );
      return rows > 0;
    });
  }

  /// Marks the issue as returned and restores each IMEI's stock_status to
  /// 'in_stock' (only those still 'with_dealer' — converted ones stay 'sold').
  @override
  Future<Result<bool>> markAsReturned(String issueId) async {
    return await guard(() async {
      bool updated = false;
      await _db.transaction((txn) async {
        final maps = await txn.query(
          TableNames.dealerIssues,
          where: 'issue_id = ?',
          whereArgs: [issueId],
          limit: 1,
        );
        if (maps.isEmpty) {
          throw AppError(code: 'not_found', message: 'Issue not found');
        }
        final issue = DealerIssueEntity.fromMap(maps.first);
        final now = DateTime.now().toIso8601String();

        for (final imei in issue.imeiList) {
          await txn.update(
            TableNames.serializedStock,
            {'stock_status': 'in_stock', 'updated_at': now},
            where: "(imei1 = ? OR imei2 = ?) AND stock_status = 'with_dealer'",
            whereArgs: [imei, imei],
          );
        }

        final rows = await txn.update(
          TableNames.dealerIssues,
          {
            'return_status': 1,
            'returned_at': now,
            'updated_at': now,
          },
          where: 'issue_id = ?',
          whereArgs: [issueId],
        );
        updated = rows > 0;
      });
      return updated;
    });
  }

  @override
  Future<Result<bool>> convertToSale(String issueId, String saleInvoiceId) async {
    return await guard(() async {
      final now = DateTime.now();
      final rows = await _db.update(
        TableNames.dealerIssues,
        {
          'converted_to_sale': 1,
          'sale_invoice_id': saleInvoiceId,
          'updated_at': now.toIso8601String(),
        },
        where: 'issue_id = ?',
        whereArgs: [issueId],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<bool>> markAsSold(String issueId) async {
    return await guard(() async {
      final now = DateTime.now();
      final rows = await _db.update(
        TableNames.dealerIssues,
        {
          'sold_status': 1,
          'updated_at': now.toIso8601String(),
        },
        where: 'issue_id = ?',
        whereArgs: [issueId],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<String>> markAsSoldViaDealer({
    required String issueId,
    required double salePrice,
    required String paymentMethod,
  }) async {
    return await guard(() async {
      String invoiceNumber = '';

      await _db.transaction((txn) async {
        final now = DateTime.now();
        final nowStr = now.toIso8601String();

        final issueMaps = await txn.query(
          TableNames.dealerIssues,
          where: 'issue_id = ?',
          whereArgs: [issueId],
          limit: 1,
        );
        if (issueMaps.isEmpty) {
          throw AppError(code: 'not_found', message: 'Issue not found');
        }
        final issue = DealerIssueEntity.fromMap(issueMaps.first);
        if (!issue.canBeConverted) {
          throw AppError(
            code: 'invalid_state',
            message: 'Issue cannot be marked as sold in its current state',
          );
        }

        final List<Map<String, Object?>> stockSnapshots = [];
        for (final imei in issue.imeiList) {
          final rows = await txn.rawQuery('''
            SELECT id, product_model_id, cost_price
            FROM ${TableNames.serializedStock}
            WHERE (imei1 = ? OR imei2 = ?) AND stock_status = 'with_dealer'
            LIMIT 1
          ''', [imei, imei]);
          if (rows.isEmpty) {
            throw AppError(
              code: 'imei_not_available',
              message: 'IMEI $imei is not currently with dealer',
            );
          }
          stockSnapshots.add(rows.first);
          await txn.update(
            TableNames.serializedStock,
            {'stock_status': 'sold', 'updated_at': nowStr},
            where: 'id = ?',
            whereArgs: [rows.first['id']],
          );
        }

        final dateStr =
            '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        await txn.rawInsert(
          'INSERT OR IGNORE INTO ${TableNames.invoiceSequences} (date_key, last_seq) VALUES (?, 0)',
          [dateStr],
        );
        await txn.rawUpdate(
          'UPDATE ${TableNames.invoiceSequences} SET last_seq = last_seq + 1 WHERE date_key = ?',
          [dateStr],
        );
        final seqResult = await txn.rawQuery(
          'SELECT last_seq FROM ${TableNames.invoiceSequences} WHERE date_key = ?',
          [dateStr],
        );
        final seq = seqResult.first['last_seq'] as int;
        invoiceNumber =
            'INV-$dateStr-${seq.toString().padLeft(4, '0')}';

        final saleId = now.microsecondsSinceEpoch.toString();
        final itemCount = stockSnapshots.length;
        final pricePerItem = itemCount > 0 ? salePrice / itemCount : salePrice;
        final paidAmount = paymentMethod == 'credit' ? 0.0 : salePrice;

        await txn.insert(TableNames.sales, {
          'id': saleId,
          'invoice_number': invoiceNumber,
          'customer_id': null,
          'user_id': null,
          'sale_date': nowStr,
          'subtotal': salePrice,
          'discount': 0.0,
          'tax': 0.0,
          'total': salePrice,
          'paid_amount': paidAmount,
          'payment_method': paymentMethod,
          'notes': 'Dealer sale – Issue #${issueId.substring(0, 8)}',
          'status': 'completed',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        for (int i = 0; i < stockSnapshots.length; i++) {
          final snap = stockSnapshots[i];
          await txn.insert(TableNames.saleItems, {
            'id': '${saleId}_$i',
            'sale_id': saleId,
            'product_model_id': snap['product_model_id'] as String,
            'serialized_stock_id': snap['id'] as String,
            'quantity': 1,
            'unit_price': pricePerItem,
            'discount': 0.0,
            'line_total': pricePerItem,
            'cost_price': (snap['cost_price'] as num?)?.toDouble() ?? 0.0,
            'created_at': nowStr,
            'updated_at': nowStr,
          });
        }

        await txn.update(
          TableNames.dealerIssues,
          {
            'sold_status': 1,
            'sale_invoice_id': invoiceNumber,
            'updated_at': nowStr,
          },
          where: 'issue_id = ?',
          whereArgs: [issueId],
        );
      });

      return invoiceNumber;
    });
  }

  /// Deletes the dealer issue. If the issue was not yet returned or converted,
  /// each IMEI is restored to 'in_stock' so the stock pool is correct.
  @override
  Future<Result<bool>> deleteIssue(String issueId) async {
    return await guard(() async {
      bool deleted = false;
      await _db.transaction((txn) async {
        final maps = await txn.query(
          TableNames.dealerIssues,
          where: 'issue_id = ?',
          whereArgs: [issueId],
          limit: 1,
        );
        if (maps.isEmpty) {
          deleted = false;
          return;
        }
        final issue = DealerIssueEntity.fromMap(maps.first);

        if (!issue.returnStatus && !issue.convertedToSale) {
          final now = DateTime.now().toIso8601String();
          for (final imei in issue.imeiList) {
            await txn.update(
              TableNames.serializedStock,
              {'stock_status': 'in_stock', 'updated_at': now},
              where: "(imei1 = ? OR imei2 = ?) AND stock_status = 'with_dealer'",
              whereArgs: [imei, imei],
            );
          }
        }

        final rows = await txn.delete(
          TableNames.dealerIssues,
          where: 'issue_id = ?',
          whereArgs: [issueId],
        );
        deleted = rows > 0;
      });
      return deleted;
    });
  }

  @override
  Future<Result<List<String>>> getAvailableImeisForIssue(String dealerId) async {
    return await guard(() async {
      final List<Map<String, dynamic>> maps = await _db.rawQuery('''
        SELECT imei1, imei2
        FROM ${TableNames.serializedStock}
        WHERE stock_status = 'in_stock'
        ORDER BY created_at DESC
      ''');

      final imeis = <String>[];
      for (final map in maps) {
        if (map['imei1'] != null) imeis.add(map['imei1'] as String);
        if (map['imei2'] != null) imeis.add(map['imei2'] as String);
      }

      return imeis;
    });
  }

  @override
  Future<Result<bool>> isImeiUniqueForDealer(String imei, String dealerId, {String? excludeIssueId}) async {
    return await guard(() async {
      String whereClause = "(imei1 = ? OR imei2 = ?) AND stock_status = 'with_dealer'";
      List<Object?> whereArgs = [imei, imei];

      if (excludeIssueId != null) {
        whereClause += ' AND issue_id != ?';
        whereArgs.add(excludeIssueId);
      }

      final List<Map<String, dynamic>> maps = await _db.rawQuery(
        'SELECT id FROM ${TableNames.serializedStock} WHERE $whereClause',
        whereArgs,
      );

      return maps.isEmpty;
    });
  }

  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on AppError catch (error) {
      return Failure(error);
    } catch (error) {
      return Failure(AppError(code: 'database_error', message: error.toString()));
    }
  }
}
