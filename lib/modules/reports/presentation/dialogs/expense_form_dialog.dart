import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

const List<String> pakistaniExpenseCategories = <String>[
  'Shop Rent',
  'Electricity Bill',
  'Internet Bill',
  'Mobile Load',
  'Employee Salary',
  'Tea / Refreshments',
  'Cleaning Expense',
  'Stationery',
  'Transport / Fuel',
  'Courier Charges',
  'Repair Tools',
  'Mobile Parts Purchase',
  'Accessory Purchase',
  'Shop Maintenance',
  'Printer Paper',
  'Thermal Roll',
  'Software Maintenance',
  'Marketing / Advertisement',
  'Tax / PTA Fee',
  'Security / CCTV',
  'Packaging Material',
  'Customer Compensation',
  'Miscellaneous',
  'Other',
];

class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({super.key, this.expense});

  final ExpenseEntity? expense;

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  late final TextEditingController _customCategoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _remarksController;
  late DateTime _expenseDate;
  late String _category;
  late String _paymentMethod;
  bool _isSubmitting = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _expenseDate = expense?.expenseDate.toLocal() ?? DateTime.now();
    _category = pakistaniExpenseCategories.contains(expense?.category)
        ? expense!.category
        : expense == null
            ? pakistaniExpenseCategories.first
            : 'Other';
    _paymentMethod =
        PaymentMethod.normalizeNullable(expense?.paymentMethod) ??
            PaymentMethod.cash;
    _customCategoryController = TextEditingController(
      text: expense?.customCategory ??
          (!pakistaniExpenseCategories.contains(expense?.category)
              ? expense?.category ?? ''
              : ''),
    );
    _amountController = TextEditingController(
      text: expense == null ? '' : FormattingHelpers.decimal(expense.amount),
    );
    _remarksController = TextEditingController(text: expense?.remarks ?? '');
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDate: _expenseDate,
                        );
                        if (picked == null) {
                          return;
                        }
                        setState(() => _expenseDate = picked);
                      },
                icon: const Icon(Icons.calendar_today),
                label: Text(FormattingHelpers.dateYmd(_expenseDate)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Expense Category',
                  isDense: true,
                ),
                items: pakistaniExpenseCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                          () => _category =
                              value ?? pakistaniExpenseCategories.first,
                        ),
              ),
              if (_category == 'Other') ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: _customCategoryController,
                  enabled: !_isSubmitting,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Custom Category',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                enabled: !_isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Payment Method',
                  isDense: true,
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: PaymentMethod.cash,
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentMethod.card,
                    child: Text('Card'),
                  ),
                  DropdownMenuItem<String>(
                    value: PaymentMethod.bank,
                    child: Text('Bank Transfer'),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                          () => _paymentMethod = value ?? PaymentMethod.cash,
                        ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _remarksController,
                enabled: !_isSubmitting,
                maxLines: 4,
                maxLength: 300,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(300),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Remarks (optional)',
                  isDense: true,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Save Expense'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final category = _category.trim();
    final customCategory = _customCategoryController.text.trim();
    if (category.isEmpty || (category == 'Other' && customCategory.isEmpty)) {
      AppNotifier.error('Category is required.');
      return;
    }
    final amount =
        FormattingHelpers.tryParseGroupedDecimalStrict(_amountController.text);
    if (amount == null || amount.isNaN) {
      AppNotifier.error('Please enter a valid amount.');
      return;
    }
    if (amount <= 0) {
      AppNotifier.error('Amount must be greater than zero.');
      return;
    }
    if (!amount.isFinite) {
      AppNotifier.error('Please enter a valid amount.');
      return;
    }
    final paymentMethod = PaymentMethod.normalizeNullable(_paymentMethod);
    if (paymentMethod == null || paymentMethod == PaymentMethod.credit) {
      AppNotifier.error('Payment method must be cash, card, or bank.');
      return;
    }

    setState(() => _isSubmitting = true);
    final repository = await ref.read(expenseRepositoryProvider.future);
    final now = DateTimeHelpers.nowUtc();
    final existing = widget.expense;
    final payload = ExpenseEntity(
      id: existing?.id ?? IdHelpers.newId(prefix: 'exp'),
      expenseDate: DateTime.utc(
        _expenseDate.year,
        _expenseDate.month,
        _expenseDate.day,
      ),
      category: category,
      customCategory: category == 'Other' ? customCategory : null,
      amount: amount,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      paymentMethod: paymentMethod,
      createdAt: existing?.createdAt ?? now,
      updatedAt: existing == null ? null : now,
    );

    final result = existing == null
        ? await repository.addExpense(payload)
        : await repository.updateExpense(payload);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success(_isEdit ? 'Expense updated.' : 'Expense added.');
    Navigator.of(context).pop(true);
  }
}
