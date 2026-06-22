import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/expense_delete_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/expense_form_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(expensesSearchRemarksProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(expensesRowsProvider);
    final summaryAsync = ref.watch(expenseAnalyticsSummaryProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final startDate = ref.watch(expensesStartDateProvider);
    final endDate = ref.watch(expensesEndDateProvider);
    final selectedCategory = ref.watch(expensesCategoryProvider);
    final selectedPaymentMethod = ref.watch(expensesPaymentMethodProvider);

    if (rowsAsync.hasError) {
      return _ExpenseErrorView(
        message: 'Failed to load expenses.',
        error: rowsAsync.error,
        onRetry: _invalidateExpenseProviders,
      );
    }

    final existingCategories = categoriesAsync.valueOrNull ?? const <String>[];
    final categoryOptions = _mergedExpenseCategories(existingCategories);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            summaryAsync.when(
              data: (summary) => _ExpenseSummaryCards(
                summary: summary,
                isCompact: isCompact,
              ),
              loading: () => const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ExpenseErrorView(
                message: 'Failed to load expense summary.',
                error: error,
                onRetry: _invalidateExpenseProviders,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => _openExpenseDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                    ReportDateFilterButton(
                      icon: Icons.calendar_today,
                      iconSize: 16,
                      emptyLabel: 'Start Date',
                      selectedDate: startDate,
                      initialDate: startDate ?? DateTime.now(),
                      onPicked: (picked) {
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesStartDateProvider.notifier).state =
                            picked;
                      },
                    ),
                    ReportDateFilterButton(
                      icon: Icons.event,
                      iconSize: 16,
                      emptyLabel: 'End Date',
                      selectedDate: endDate,
                      initialDate: endDate ?? DateTime.now(),
                      onPicked: (picked) {
                        if (picked == null) {
                          return;
                        }
                        ref.read(expensesEndDateProvider.notifier).state =
                            picked;
                      },
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            selectedCategory.isEmpty ? null : selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Category',
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All Categories'),
                          ),
                          ...categoryOptions.map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          ref.read(expensesCategoryProvider.notifier).state =
                              value ?? '';
                        },
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPaymentMethod.isEmpty
                            ? null
                            : selectedPaymentMethod,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Payment',
                          isDense: true,
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text('All Payments'),
                          ),
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
                        onChanged: (value) {
                          ref
                              .read(expensesPaymentMethodProvider.notifier)
                              .state = value ?? '';
                        },
                      ),
                    ),
                    SizedBox(
                      width: isCompact ? constraints.maxWidth : 260,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(expensesSearchRemarksProvider.notifier)
                            .state = value,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Search remarks',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          expensesSearchRemarksProvider
                                              .notifier,
                                        )
                                        .state = '';
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: rowsAsync.when(
                data: (rows) => _ExpensesTableSection(
                  rows: rows,
                  isCompact: isCompact,
                  onAdd: () => _openExpenseDialog(),
                  onEdit: (expense) => _openExpenseDialog(expense: expense),
                  onDelete: _confirmDeleteExpense,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ExpenseErrorView(
                  message: 'Failed to load expenses.',
                  error: error,
                  onRetry: _invalidateExpenseProviders,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearFilters() {
    ref.read(expensesStartDateProvider.notifier).state = null;
    ref.read(expensesEndDateProvider.notifier).state = null;
    ref.read(expensesCategoryProvider.notifier).state = '';
    ref.read(expensesPaymentMethodProvider.notifier).state = '';
    ref.read(expensesSearchRemarksProvider.notifier).state = '';
    _searchController.clear();
    setState(() {});
  }

  Future<void> _openExpenseDialog({ExpenseEntity? expense}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => ExpenseFormDialog(expense: expense),
    );
    if (changed == true && mounted) {
      _invalidateExpenseProviders();
    }
  }

  Future<void> _confirmDeleteExpense(ExpenseEntity expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ExpenseDeleteDialog(expense: expense),
    );
    if (confirmed != true) {
      return;
    }
    final repository = await ref.read(expenseRepositoryProvider.future);
    final result = await repository.deleteExpense(expense.id);
    if (!mounted) {
      return;
    }
    if (result.isFailure) {
      AppNotifier.errorFromAppError(result.asFailure!.error);
      return;
    }
    AppNotifier.success('Expense deleted.');
    _invalidateExpenseProviders();
  }

  void _invalidateExpenseProviders() {
    ref.read(reportWorkflowCoordinatorProvider).refreshExpenseReports();
  }
}

class _ExpenseSummaryCards extends StatelessWidget {
  const _ExpenseSummaryCards({
    required this.summary,
    required this.isCompact,
  });

  final ExpenseAnalyticsSummary summary;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final cards = <Widget>[
      ReportSummaryCardWidget(
        label: 'Today\'s Expense',
        value: FormattingHelpers.currencyPkr(summary.todayTotal),
        color: semantic.danger,
      ),
      ReportSummaryCardWidget(
        label: 'Monthly Expense',
        value: FormattingHelpers.currencyPkr(summary.thisMonthTotal),
        color: semantic.warning,
      ),
      ReportSummaryCardWidget(
        label: 'Total Expense',
        value: FormattingHelpers.currencyPkr(summary.allTimeTotal),
        color: theme.colorScheme.primary,
      ),
      ReportSummaryCardWidget(
        label: 'Highest Expense Category',
        value: summary.highestCategory ?? '-',
        color: theme.colorScheme.primary,
      ),
    ];

    if (isCompact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(width: double.infinity, child: card),
              ),
            )
            .toList(growable: false),
      );
    }

    return Row(
      children: <Widget>[
        for (var index = 0; index < cards.length; index++) ...<Widget>[
          Expanded(child: cards[index]),
          if (index != cards.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ExpenseErrorView extends StatelessWidget {
  const _ExpenseErrorView({
    required this.message,
    this.error,
    required this.onRetry,
  });

  final String message;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final details = error == null
        ? null
        : error is AppError
            ? (error as AppError).message
            : '$error';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(message)),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
            if (details != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(details, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpensesTableSection extends StatelessWidget {
  const _ExpensesTableSection({
    required this.rows,
    required this.isCompact,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final bool isCompact;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ReportTableSection(
        title: 'Expense Records',
        subtitle: 'No expenses found for the current filters.',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('No expenses found'),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
            ],
          ),
        ),
      );
    }

    final total = rows.fold<double>(0, (sum, expense) => sum + expense.amount);
    return ReportTableSection(
      title: 'Expense Records',
      subtitle: '${rows.length} rows | ${FormattingHelpers.currencyPkr(total)}',
      child: isCompact
          ? _ExpenseCardList(
              rows: rows,
              onEdit: onEdit,
              onDelete: onDelete,
            )
          : _ExpenseDesktopTable(
              rows: rows,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
    );
  }
}

class _ExpenseDesktopTable extends StatelessWidget {
  const _ExpenseDesktopTable({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final layout = reportTableLayoutFor(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1040,
        child: AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 88,
          showCheckboxColumn: false,
          emptyMessage: 'No expenses found',
          columns: <DataColumn>[
            DataColumn(
              label: reportStyledTableHeaderCell(context, 'Date', width: 110),
            ),
            DataColumn(
              label: reportStyledTableHeaderCell(
                context,
                'Category',
                width: 170,
              ),
            ),
            DataColumn(
              label: reportStyledTableHeaderCell(
                context,
                'Remarks',
                width: 360,
              ),
            ),
            DataColumn(
              label: reportStyledTableHeaderCell(
                context,
                'Payment Method',
                width: 130,
              ),
            ),
            DataColumn(
              numeric: true,
              label: reportStyledTableHeaderCell(context, 'Amount', width: 120),
            ),
            DataColumn(
              label: reportStyledTableHeaderCell(
                context,
                'Actions',
                width: 110,
              ),
            ),
          ],
          rows: rows
              .map(
                (expense) => DataRow(
                  cells: <DataCell>[
                    DataCell(
                      reportStyledTableCell(
                        FormattingHelpers.dateYmd(expense.expenseDate),
                        width: 110,
                      ),
                    ),
                    DataCell(
                      reportStyledTableCell(
                        expense.displayCategory,
                        width: 170,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 360,
                        child: Text(
                          expense.remarks?.trim().isNotEmpty == true
                              ? expense.remarks!.trim()
                              : '-',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ),
                    ),
                    DataCell(
                      reportStyledTableCell(
                        _paymentMethodLabel(expense.paymentMethod),
                        width: 130,
                      ),
                    ),
                    DataCell(
                      reportStyledTableCell(
                        FormattingHelpers.currencyPkr(expense.amount),
                        width: 120,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(expense),
                              icon: const Icon(Icons.edit, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => onDelete(expense),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ExpenseCardList extends StatelessWidget {
  const _ExpenseCardList({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ExpenseEntity> rows;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final expense = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        expense.displayCategory,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      FormattingHelpers.currencyPkr(expense.amount),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${FormattingHelpers.dateYmd(expense.expenseDate)} | ${_paymentMethodLabel(expense.paymentMethod)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (expense.remarks?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(expense.remarks!.trim()),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEdit(expense),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => onDelete(expense),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<String> _mergedExpenseCategories(List<String> existingCategories) {
  final seen = <String>{};
  final output = <String>[];
  for (final category in <String>[
    ...pakistaniExpenseCategories,
    ...existingCategories,
  ]) {
    final normalized = category.trim();
    if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) {
      continue;
    }
    output.add(normalized);
  }
  return output;
}

String _paymentMethodLabel(String? paymentMethod) {
  final normalized = PaymentMethod.normalizeNullable(paymentMethod);
  return normalized == null
      ? '-'
      : PaymentMethod.labels[normalized] ?? normalized;
}
