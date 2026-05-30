import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/repositories/expense_repository.dart';

class SqliteExpenseRepository
    with BaseRepositoryGuard
    implements ExpenseRepository {
  SqliteExpenseRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<void>> addExpense(ExpenseEntity expense) {
    return guard<void>(() async {
      _validateAmount(expense.amount);
      final normalizedCategory = _normalizeCategory(expense.category);
      if (normalizedCategory.isEmpty) {
        throw StateError('Expense category is required.');
      }
      await _appDatabase.insert(TableNames.expenses, <String, Object?>{
        'id': expense.id,
        'expense_date': DateTimeHelpers.toSql(expense.expenseDate),
        'category': normalizedCategory,
        'custom_category':
            NotesSafety.normalizeNullable(expense.customCategory),
        'amount': expense.amount,
        'remarks': NotesSafety.normalizeNullable(expense.remarks),
        'notes': NotesSafety.normalizeNullable(expense.remarks),
        'payment_method': expense.paymentMethod?.trim().isNotEmpty == true
            ? expense.paymentMethod!.trim()
            : null,
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
      _validateAmount(expense.amount);
      final normalizedCategory = _normalizeCategory(expense.category);
      if (normalizedCategory.isEmpty) {
        throw StateError('Expense category is required.');
      }
      await _appDatabase.update(
        TableNames.expenses,
        <String, Object?>{
          'expense_date': DateTimeHelpers.toSql(expense.expenseDate),
          'category': normalizedCategory,
          'custom_category':
              NotesSafety.normalizeNullable(expense.customCategory),
          'amount': expense.amount,
          'remarks': NotesSafety.normalizeNullable(expense.remarks),
          'notes': NotesSafety.normalizeNullable(expense.remarks),
          'payment_method': expense.paymentMethod?.trim().isNotEmpty == true
              ? expense.paymentMethod!.trim()
              : null,
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
  Future<Result<List<ExpenseEntity>>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
    int offset = 0,
  }) {
    return getExpenses(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Result<List<ExpenseEntity>>> searchExpenses(
    String query, {
    int limit = 500,
    int offset = 0,
  }) {
    return getExpenses(
      searchRemarks: query,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Result<List<ExpenseEntity>>> filterExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? paymentMethod,
    String? searchRemarks,
    int limit = 500,
    int offset = 0,
  }) {
    return getExpenses(
      startDate: startDate,
      endDate: endDate,
      category: category,
      paymentMethod: paymentMethod,
      searchRemarks: searchRemarks,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Result<List<ExpenseEntity>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? paymentMethod,
    String? searchRemarks,
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

      final normalizedPaymentMethod = paymentMethod?.trim() ?? '';
      if (normalizedPaymentMethod.isNotEmpty) {
        where.add('payment_method = ?');
        args.add(normalizedPaymentMethod);
      }

      final normalizedRemarks = searchRemarks?.trim() ?? '';
      if (normalizedRemarks.isNotEmpty) {
        where.add('(remarks LIKE ? OR custom_category LIKE ?)');
        final like = '%$normalizedRemarks%';
        args.add(like);
        args.add(like);
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

  @override
  Future<Result<ExpenseAnalyticsSummary>> getExpenseSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return getAnalyticsSummary(startDate: startDate, endDate: endDate);
  }

  @override
  Future<Result<ExpenseAnalyticsSummary>> getAnalyticsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return guard<ExpenseAnalyticsSummary>(() async {
      final where = <String>['is_deleted = 0'];
      final args = <Object?>[];

      final nowUtc = DateTimeHelpers.nowUtc();
      final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final monthStart = DateTime.utc(nowUtc.year, nowUtc.month);

      if (startDate != null) {
        where.add('expense_date >= ?');
        args.add(DateTimeHelpers.toSql(
            DateTime.utc(startDate.year, startDate.month, startDate.day)));
      }
      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        where.add('expense_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final whereClause = where.join(' AND ');

      // Today total
      final todayRows = await _appDatabase.database.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM ${TableNames.expenses}
        WHERE is_deleted = 0
          AND expense_date >= ?
          AND expense_date < ?
        ''',
        [
          DateTimeHelpers.toSql(todayStart),
          DateTimeHelpers.toSql(todayStart.add(const Duration(days: 1))),
        ],
      );
      final todayTotal = (todayRows.first['total'] as num?)?.toDouble() ?? 0.0;

      // This month total
      final monthRows = await _appDatabase.database.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM ${TableNames.expenses}
        WHERE is_deleted = 0
          AND expense_date >= ?
        ''',
        [DateTimeHelpers.toSql(monthStart)],
      );
      final monthTotal = (monthRows.first['total'] as num?)?.toDouble() ?? 0.0;

      // All-time total (within filter)
      final totalRows = await _appDatabase.database.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM ${TableNames.expenses}
        WHERE $whereClause
        ''',
        args,
      );
      final allTimeTotal =
          (totalRows.first['total'] as num?)?.toDouble() ?? 0.0;

      // Highest-spend category
      final highestCategoryRows = await _appDatabase.database.rawQuery(
        '''
        SELECT category, COALESCE(SUM(amount), 0) AS total
        FROM ${TableNames.expenses}
        WHERE $whereClause
        GROUP BY category
        ORDER BY total DESC
        LIMIT 1
        ''',
        args,
      );
      final highestCategory = highestCategoryRows.isEmpty
          ? null
          : (highestCategoryRows.first['category'] as String?);
      final highestCategoryTotal = highestCategoryRows.isEmpty
          ? 0.0
          : (highestCategoryRows.first['total'] as num?)?.toDouble() ?? 0.0;

      // Most frequent category
      final frequentCategoryRows = await _appDatabase.database.rawQuery(
        '''
        SELECT category, COUNT(*) AS cnt
        FROM ${TableNames.expenses}
        WHERE $whereClause
        GROUP BY category
        ORDER BY cnt DESC
        LIMIT 1
        ''',
        args,
      );
      final mostFrequentCategory = frequentCategoryRows.isEmpty
          ? null
          : (frequentCategoryRows.first['category'] as String?);

      return ExpenseAnalyticsSummary(
        todayTotal: todayTotal,
        thisMonthTotal: monthTotal,
        allTimeTotal: allTimeTotal,
        highestCategory: highestCategory,
        highestCategoryTotal: highestCategoryTotal,
        mostFrequentCategory: mostFrequentCategory,
      );
    }, operation: 'get_expense_analytics');
  }

  String _normalizeCategory(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) {
      return '';
    }
    final lower = collapsed.toLowerCase();
    final output = StringBuffer();
    var capitalizeNext = true;
    for (var index = 0; index < lower.length; index++) {
      final char = lower[index];
      final isAlphaNumeric = RegExp(r'[a-z0-9]').hasMatch(char);
      if (isAlphaNumeric) {
        output.write(capitalizeNext ? char.toUpperCase() : char);
        capitalizeNext = false;
        continue;
      }
      output.write(char);
      capitalizeNext = true;
    }
    return output.toString();
  }

  void _validateAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw StateError('Expense amount must be greater than zero.');
    }
  }

  ExpenseEntity _toEntity(Map<String, Object?> row) {
    // Backward-compat: old rows used `notes`; new rows use `remarks`.
    // Both columns are present after v23 migration.
    final remarksRaw = (row['remarks'] as String?) ?? (row['notes'] as String?);
    return ExpenseEntity(
      id: row['id'] as String,
      expenseDate: DateTimeHelpers.fromSql(row['expense_date'] as String),
      category: row['category'] as String,
      customCategory: (row['custom_category'] as String?)?.isNotEmpty == true
          ? row['custom_category'] as String
          : null,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      remarks: remarksRaw?.isNotEmpty == true ? remarksRaw : null,
      paymentMethod: (row['payment_method'] as String?)?.isNotEmpty == true
          ? row['payment_method'] as String
          : null,
      createdAt: DateTimeHelpers.fromSql(row['created_at'] as String),
      updatedAt: (row['updated_at'] as String?) == null
          ? null
          : DateTimeHelpers.fromSql(row['updated_at'] as String),
    );
  }
}
