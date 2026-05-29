import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/reports/data/repositories/sqlite_expense_repository.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';

abstract class ExpenseRepository extends BaseRepository {
  Future<Result<void>> addExpense(ExpenseEntity expense);

  Future<Result<void>> updateExpense(ExpenseEntity expense);

  Future<Result<void>> deleteExpense(String expenseId);

  Future<Result<List<ExpenseEntity>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? paymentMethod,
    String? searchRemarks,
    int limit = 500,
    int offset = 0,
  });

  Future<Result<List<String>>> getExpenseCategories();

  Future<Result<ExpenseAnalyticsSummary>> getAnalyticsSummary({
    DateTime? startDate,
    DateTime? endDate,
  });
}
