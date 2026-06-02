import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';

class ExpenseDeleteDialog extends StatelessWidget {
  const ExpenseDeleteDialog({super.key, required this.expense});

  final ExpenseEntity expense;

  @override
  Widget build(BuildContext context) {
    return AppConfirmationDialog(
      title: 'Delete Expense',
      message:
          'Delete ${expense.displayCategory} expense of ${FormattingHelpers.currencyPkr(expense.amount)}? This will remove it from cash movement reports.',
      confirmLabel: 'Delete',
    );
  }
}
