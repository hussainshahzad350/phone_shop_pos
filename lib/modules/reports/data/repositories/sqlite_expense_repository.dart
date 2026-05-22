import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/repositories/expense_repository.dart';

class SqliteExpenseRepository with BaseRepositoryGuard implements ExpenseRepository {
  SqliteExpenseRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<void>> addExpense(ExpenseEntity expense) {
    return guard<void>(() async {
      await _appDatabase.insert(TableNames.expenses, <String, Object?>{
        'id': expense.id,
        'expense_date': DateTimeHelpers.toSql(expense.expenseDate),
        'category': expense.category.trim(),
        'amount': expense.amount,
        'notes': NotesSafety.normalizeNullable(expense.notes),
        'created_at': DateTimeHelpers.toSql(expense.createdAt),
        'updated_at': expense.updatedAt == null
            ? null
            : DateTimeHelpers.toSql(expense.updatedAt!),
        'is_deleted': 0,
      });
    }, operation: 'add_expense');
  }

  @override
  Future<Result<void>> updateExpense(ExpenseEntity expense) {
    return guard<void>(() async {
      await _appDatabase.update(
        TableNames.expenses,
        <String, Object?>{
          'expense_date': DateTimeHelpers.toSql(expense.expenseDate),
          'category': expense.category.trim(),
          'amount': expense.amount,
          'notes': NotesSafety.normalizeNullable(expense.notes),
          'updated_at': expense.updatedAt == null
              ? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc())
              : DateTimeHelpers.toSql(expense.updatedAt!),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object?>[expense.id],
      );
    }, operation: 'update_expense');
  }

  @override
  Future<Result<void>> deleteExpense(String expenseId) {
    return guard<void>(() async {
      await _appDatabase.update(
        TableNames.expenses,
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object?>[expenseId],
      );
    }, operation: 'delete_expense');
  }

  @override
  Future<Result<List<ExpenseEntity>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int limit = 500,
    int offset = 0,
  }) {
    return guard<List<ExpenseEntity>>(() async {
      final where = <String>['is_deleted = 0'];
      final args = <Object?>[];

      if (startDate != null) {
        final startUtc =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
        where.add('expense_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }
      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        where.add('expense_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final normalizedCategory = category?.trim() ?? '';
      if (normalizedCategory.isNotEmpty) {
        where.add('category = ?');
        args.add(normalizedCategory);
      }

      final rows = await QueryDiagnostics.trace(
        label: 'reports.expenses.list',
        action: () => _appDatabase.database.query(
          TableNames.expenses,
          where: where.join(' AND '),
          whereArgs: args,
          orderBy: 'expense_date DESC, created_at DESC',
          limit: limit,
          offset: offset,
        ),
      );

      return rows.map(_toEntity).toList(growable: false);
    }, operation: 'get_expenses');
  }

  @override
  Future<Result<List<String>>> getExpenseCategories() {
    return guard<List<String>>(() async {
      final rows = await QueryDiagnostics.trace(
        label: 'reports.expenses.categories',
        action: () => _appDatabase.database.rawQuery(
          '''
          SELECT DISTINCT category
          FROM ${TableNames.expenses}
          WHERE is_deleted = 0
            AND TRIM(category) != ''
          ORDER BY category COLLATE NOCASE ASC
          ''',
        ),
      );
      return rows
          .map((row) => (row['category'] as String?)?.trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }, operation: 'get_expense_categories');
  }

  ExpenseEntity _toEntity(Map<String, Object?> row) {
    return ExpenseEntity(
      id: row['id'] as String,
      expenseDate: DateTimeHelpers.fromSql(row['expense_date'] as String),
      category: row['category'] as String,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      notes: row['notes'] as String?,
      createdAt: DateTimeHelpers.fromSql(row['created_at'] as String),
      updatedAt: (row['updated_at'] as String?) == null
          ? null
          : DateTimeHelpers.fromSql(row['updated_at'] as String),
    );
  }
}
