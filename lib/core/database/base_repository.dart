import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';

abstract class BaseRepository {
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  });
}

mixin BaseRepositoryGuard on BaseRepository {
  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async {
    try {
      final value = await action();
      return Success<T>(value);
    } on DatabaseException catch (error) {
      final lowerMessage = error.toString().toLowerCase();
      if (lowerMessage.contains('database is locked') ||
          lowerMessage.contains('database is busy')) {
        return Failure<T>(
          AppError(
            code: 'database_locked',
            message:
                'Database is temporarily locked by another process. Retry after a moment.',
            details: error,
          ),
        );
      }
      return Failure<T>(
        AppError(
          code: 'database_error',
          message: 'Database error during $operation',
          details: error,
        ),
      );
    } on FormatException catch (error) {
      return Failure<T>(
        AppError(
          code: 'format_error',
          message: 'Data format error during $operation',
          details: error,
        ),
      );
    } catch (error) {
      return Failure<T>(
        AppError(
          code: 'unknown_error',
          message: 'Unexpected error during $operation',
          details: error,
        ),
      );
    }
  }
}
