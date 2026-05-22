class ExpenseEntity {
  const ExpenseEntity({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseEntity copyWith({
    String? id,
    DateTime? expenseDate,
    String? category,
    double? amount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNotes = false,
    bool clearUpdatedAt = false,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      notes: clearNotes ? null : notes ?? this.notes,
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
        other.amount == amount &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        expenseDate,
        category,
        amount,
        notes,
        createdAt,
        updatedAt,
      );
}
