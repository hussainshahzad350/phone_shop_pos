import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/repositories/dealer_issue_repository.dart';

class SqliteDealerIssueRepository implements DealerIssueRepository {
  final AppDatabase _appDatabase;

  SqliteDealerIssueRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  static const String _tableName = 'dealer_issues';

  Future<Database> get _database async => _appDatabase.database;

  @override
  Future<Result<List<DealerIssueEntity>>> getAllIssues() async {
    return await guard(() async {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'issue_date DESC',
      );
      return maps.map((map) => DealerIssueEntity.fromMap(map)).toList();
    });
  }

  @override
  Future<Result<DealerIssueEntity>> getIssueById(String issueId) async {
    return await guard(() async {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
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
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
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
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'sold_status = ?',
        whereArgs: [status == 'Sold' ? 1 : 0],
        orderBy: 'issue_date DESC',
      );
      return maps.map((map) => DealerIssueEntity.fromMap(map)).toList();
    });
  }

  @override
  Future<Result<DealerIssueEntity>> createIssue(DealerIssueEntity issue) async {
    return await guard(() async {
      final db = await _database;

      await db.insert(_tableName, issue.toMap());

      return issue;
    });
  }

  @override
  Future<Result<bool>> updateIssue(DealerIssueEntity issue) async {
    return await guard(() async {
      final db = await _database;
      final rows = await db.update(
        _tableName,
        issue.toMap(),
        where: 'issue_id = ?',
        whereArgs: [issue.issueId],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<bool>> deleteIssue(String issueId) async {
    return await guard(() async {
      final db = await _database;
      final rows = await db.delete(
        _tableName,
        where: 'issue_id = ?',
        whereArgs: [issueId],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<bool>> markAsReturned(String issueId) async {
    return await guard(() async {
      final db = await _database;
      final now = DateTime.now();
      final rows = await db.update(
        _tableName,
        {
          'return_status': 1,
          'returned_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'issue_id = ?',
        whereArgs: [issueId],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<bool>> convertToSale(String issueId, String saleInvoiceId) async {
    return await guard(() async {
      final db = await _database;
      final now = DateTime.now();
      final rows = await db.update(
        _tableName,
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
      final db = await _database;
      final now = DateTime.now();
      final rows = await db.update(
        _tableName,
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
  Future<Result<List<String>>> getAvailableImeisForIssue(String dealerId) async {
    return await guard(() async {
      final db = await _database;

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT imei1, imei2
        FROM serialized_stock
        WHERE serialized_status = 'in_stock'
        AND id IN (
          SELECT stock_id FROM inventory_stock WHERE dealer_id = ?
        )
      ''', [dealerId]);

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
      final db = await _database;

      String whereClause = 'imei1 = ? OR imei2 = ?';
      List<Object?> whereArgs = [imei, imei];

      if (excludeIssueId != null) {
        whereClause += ' AND issue_id != ?';
        whereArgs.add(excludeIssueId);
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT id FROM serialized_stock
        WHERE $whereClause
        AND id IN (
          SELECT stock_id FROM inventory_stock WHERE dealer_id = ?
        )
      ''', whereArgs);

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