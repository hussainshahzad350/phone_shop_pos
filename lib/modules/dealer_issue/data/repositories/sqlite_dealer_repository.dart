import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/repositories/dealer_repository.dart';

class SqliteDealerRepository implements DealerRepository {
  SqliteDealerRepository({required AppDatabase appDatabase})
      : _db = appDatabase.database;

  final Database _db;

  @override
  Future<Result<List<DealerEntity>>> getAllDealers() async {
    return _guard(() async {
      final rows = await _db.query(
        TableNames.dealers,
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
      return rows.map(DealerEntity.fromMap).toList(growable: false);
    });
  }

  @override
  Future<Result<DealerEntity>> createDealer(DealerEntity dealer) async {
    return _guard(() async {
      await _db.insert(TableNames.dealers, dealer.toMap());
      return dealer;
    });
  }

  @override
  Future<Result<bool>> updateDealer(DealerEntity dealer) async {
    return _guard(() async {
      final rows = await _db.update(
        TableNames.dealers,
        dealer.toMap(),
        where: 'id = ?',
        whereArgs: [dealer.id],
      );
      return rows > 0;
    });
  }

  @override
  Future<Result<bool>> deleteDealer(String dealerId) async {
    return _guard(() async {
      final rows = await _db.update(
        TableNames.dealers,
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [dealerId],
      );
      return rows > 0;
    });
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on AppError catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(AppError(code: 'database_error', message: e.toString()));
    }
  }
}
