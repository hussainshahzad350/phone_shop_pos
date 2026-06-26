import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class CashFlowTab extends ConsumerWidget {
  const CashFlowTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(cashLedgerRowsProvider);
    final startDate = ref.watch(cashLedgerStartDateProvider);
    final endDate = ref.watch(cashLedgerEndDateProvider);

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ReportDateFilterButton(
                  icon: Icons.calendar_today,
                  emptyLabel: 'Start Date',
                  selectedDate: startDate,
                  initialDate:
                      ref.read(cashLedgerStartDateProvider) ?? DateTime.now(),
                  onPicked: (picked) {
                    ref.read(cashLedgerStartDateProvider.notifier).state =
                        picked;
                  },
                ),
                ReportDateFilterButton(
                  icon: Icons.event,
                  emptyLabel: 'End Date',
                  selectedDate: endDate,
                  initialDate:
                      ref.read(cashLedgerEndDateProvider) ?? DateTime.now(),
                  onPicked: (picked) {
                    ref.read(cashLedgerEndDateProvider.notifier).state = picked;
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(cashLedgerStartDateProvider.notifier).state = null;
                    ref.read(cashLedgerEndDateProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Dates'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              final summary = ref.watch(cashFlowPageSummaryProvider);

              return Column(
                children: <Widget>[
                  ReportSummaryRow(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Cash in (page)',
                          value: FormattingHelpers.currencyPkr(
                            summary.totalCashIn,
                          ),
                          color: Theme.of(context).semantic.success,
                        ),
                      ),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Net cash (page)',
                          value: FormattingHelpers.currencyPkr(summary.netCash),
                          color: summary.netCash >= 0
                              ? Theme.of(context).semantic.success
                              : Theme.of(context).semantic.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReportTableSection(
                      title: 'Cash Flow',
                      subtitle:
                          'Cash movement only (sales, collections, refunds, purchases paid, expenses). Not physical drawer cash.',
                      child: AppDataTable(
                        emptyMessage:
                            'No cash flow rows in selected date range.',
                        columnSpacing:
                            reportTableLayoutFor(context).columnSpacing,
                        dataRowMinHeight:
                            reportTableLayoutFor(context).dataRowMinHeight,
                        dataRowMaxHeight:
                            reportTableLayoutFor(context).dataRowMaxHeight,
                        showCheckboxColumn: false,
                        columns: <DataColumn>[
                          DataColumn(
                            label: reportStyledTableHeaderCell(context, '#',
                                width: 48),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(context, 'Day',
                                width: 105),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Cash Sales In (PKR)',
                                width: 140),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Collections In (PKR)',
                                width: 145),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Total Cash In (PKR)',
                                width: 140),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Purchase Refunds In (PKR)',
                                width: 175),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Cash Refunds Out (PKR)',
                                width: 160),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Purchases Paid Out (PKR)',
                                width: 175),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Expenses Out (PKR)',
                                width: 145),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Total Cash Out (PKR)',
                                width: 145),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                                context, 'Net Cash (PKR)',
                                width: 130),
                          ),
                        ],
                        rows: rows.asMap().entries.map((entry) {
                          final row = entry.value;
                          final colorScheme = Theme.of(context).colorScheme;
                          final isNegative = row.netCash < 0;
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(reportStyledTableCell(
                                  '${entry.key + 1}', width: 48)),
                              DataCell(
                                  reportStyledTableCell(row.day, width: 105)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.cashSalesIn),
                                  width: 140)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(
                                      row.cashCollectionsIn),
                                  width: 145)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.totalCashIn),
                                  width: 140)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(
                                      row.purchaseRefundsIn),
                                  width: 175)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.cashRefundsOut),
                                  width: 160)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(
                                      row.purchasePaymentsOut),
                                  width: 175)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.expensesOut),
                                  width: 145)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.decimal(row.totalCashOut),
                                  width: 145)),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: reportStyledStatusCell(
                                      context,
                                      FormattingHelpers.decimal(row.netCash),
                                      isNegative
                                          ? colorScheme.errorContainer
                                          : colorScheme.primaryContainer,
                                      isNegative
                                          ? colorScheme.onErrorContainer
                                          : colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Failed to load cash flow.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(cashLedgerRowsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
