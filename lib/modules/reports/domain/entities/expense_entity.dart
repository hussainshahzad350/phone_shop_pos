/// Represents a single expense entry for the Phone Shop POS.
///
/// Fields added in v23:
///  - [customCategory] holds the user-supplied name when [category] == 'Other'
///  - [remarks]        replaces the old `notes` column for structured detail
///  - [paymentMethod]  tracks how the expense was paid
class ExpenseEntity {
  const ExpenseEntity({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.createdAt,
    this.customCategory,
    this.remarks,
    this.paymentMethod,
    this.updatedAt,
  });

  final String id;
  final DateTime expenseDate;

  /// Predefined category label, e.g. "Electricity Bill".
  /// When the user picks "Other", this is exactly 'Other'.
  final String category;

  /// The user-typed name when [category] == 'Other'.
  final String? customCategory;

  final double amount;

  /// Free-form human-readable detail, e.g. "June WAPDA bill".
  final String? remarks;

  /// Payment method used: cash / card / bank, or null if unspecified.
  final String? paymentMethod;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// The display label shown in the UI and reports.
  String get displayCategory =>
      (category == 'Other' && (customCategory?.trim().isNotEmpty ?? false))
          ? customCategory!.trim()
          : category;

  ExpenseEntity copyWith({
    String? id,
    DateTime? expenseDate,
    String? category,
    String? customCategory,
    double? amount,
    String? remarks,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCustomCategory = false,
    bool clearRemarks = false,
    bool clearPaymentMethod = false,
    bool clearUpdatedAt = false,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      customCategory:
          clearCustomCategory ? null : customCategory ?? this.customCategory,
      amount: amount ?? this.amount,
      remarks: clearRemarks ? null : remarks ?? this.remarks,
      paymentMethod:
          clearPaymentMethod ? null : paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ExpenseEntity &&
        other.id == id &&
        other.expenseDate == expenseDate &&
        other.category == category &&
        other.customCategory == customCategory &&
        other.amount == amount &&
        other.remarks == remarks &&
        other.paymentMethod == paymentMethod &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        expenseDate,
        category,
        customCategory,
        amount,
        remarks,
        paymentMethod,
        createdAt,
        updatedAt,
      );
}

/// Analytics summary for the expense dashboard.
class ExpenseAnalyticsSummary {
  const ExpenseAnalyticsSummary({
    required this.todayTotal,
    required this.thisMonthTotal,
    required this.allTimeTotal,
    required this.highestCategory,
    required this.highestCategoryTotal,
    required this.mostFrequentCategory,
  });

  final double todayTotal;
  final double thisMonthTotal;
  final double allTimeTotal;
  final String? highestCategory;
  final double highestCategoryTotal;
  final String? mostFrequentCategory;
}
