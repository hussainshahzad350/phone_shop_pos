import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class RepairAnalyticsTab extends ConsumerWidget {
  const RepairAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDate = ref.watch(reportRepairAnalyticsStartDateProvider);
    final endDate = ref.watch(reportRepairAnalyticsEndDateProvider);
    final analyticsAsync = ref.watch(reportRepairAnalyticsProvider);

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: () {
                    final now = DateTime.now();
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = DateTime(now.year, now.month, 1);
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = DateTime(now.year, now.month + 1, 0);
                  },
                  child: const Text('This Month'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final now = DateTime.now();
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = DateTime(now.year, 1, 1);
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = DateTime(now.year, 12, 31);
                  },
                  child: const Text('This Year'),
                ),
                ReportDateFilterButton(
                  icon: Icons.calendar_today,
                  iconSize: 16,
                  emptyLabel: 'Start Date',
                  selectedDate: startDate,
                  initialDate: startDate ?? DateTime.now(),
                  onPicked: (picked) {
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = picked;
                  },
                ),
                ReportDateFilterButton(
                  icon: Icons.event,
                  iconSize: 16,
                  emptyLabel: 'End Date',
                  selectedDate: endDate,
                  initialDate: endDate ?? DateTime.now(),
                  onPicked: (picked) {
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = picked;
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(reportRepairAnalyticsStartDateProvider.notifier)
                        .state = null;
                    ref
                        .read(reportRepairAnalyticsEndDateProvider.notifier)
                        .state = null;
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('All Time'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: analyticsAsync.when(
            data: (analytics) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Repairs',
                          value: analytics.totalRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Delivered',
                          value: analytics.deliveredRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Pending',
                          value: analytics.pendingRepairs.toString(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Earnings',
                          value: FormattingHelpers.currencyPkr(
                              analytics.totalEarnings),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total Expenses',
                          value: FormattingHelpers.currencyPkr(
                              analytics.totalExpenses),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 300,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _AnalyticsTable(
                            title: 'Issue Analysis',
                            minHeight: 220,
                            columns: <DataColumn>[
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Issue',
                                    width: 200),
                              ),
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Count',
                                    width: 80),
                              ),
                            ],
                            rows: analytics.issueGroups
                                .map(
                                  (g) => DataRow(
                                    cells: <DataCell>[
                                      DataCell(reportStyledTableCell(g.issue,
                                          width: 200)),
                                      DataCell(reportStyledTableCell(
                                          g.count.toString(),
                                          width: 80)),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            emptyMessage: 'No issues recorded.',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _AnalyticsTable(
                            title: 'Top Phone Models',
                            minHeight: 220,
                            columns: <DataColumn>[
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Model',
                                    width: 200),
                              ),
                              DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Repairs',
                                    width: 80),
                              ),
                            ],
                            rows: analytics.topModels
                                .map(
                                  (m) => DataRow(
                                    cells: <DataCell>[
                                      DataCell(reportStyledTableCell(m.model,
                                          width: 200)),
                                      DataCell(reportStyledTableCell(
                                          m.count.toString(),
                                          width: 80)),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            emptyMessage: 'No data.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AnalyticsTable(
                    title: 'Monthly Trend',
                    minHeight: 180,
                    columns: <DataColumn>[
                      DataColumn(
                        label: reportStyledTableHeaderCell(context, 'Month',
                            width: 120),
                      ),
                      DataColumn(
                        label: reportStyledTableHeaderCell(context, 'Repairs',
                            width: 90),
                      ),
                      DataColumn(
                        label: reportStyledTableHeaderCell(
                            context, 'Earnings (PKR)',
                            width: 140),
                      ),
                    ],
                    rows: analytics.monthlyTrend
                        .map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(
                                  reportStyledTableCell(row.month, width: 120)),
                              DataCell(reportStyledTableCell(
                                  row.repairs.toString(),
                                  width: 90)),
                              DataCell(reportStyledTableCell(
                                  FormattingHelpers.currencyPkr(row.earnings),
                                  width: 140)),
                            ],
                          ),
                        )
                        .toList(growable: false),
                    emptyMessage: 'No monthly data.',
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Failed to load repair analytics.'),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(reportRepairAnalyticsProvider),
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

class _AnalyticsTable extends StatelessWidget {
  const _AnalyticsTable({
    required this.title,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    this.minHeight = 200,
  });

  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final layout = reportTableLayoutFor(context);

    final indexedColumns = <DataColumn>[
      DataColumn(
        label: reportStyledTableHeaderCell(context, '#', width: 40),
      ),
      ...columns,
    ];
    final indexedRows = List<DataRow>.generate(
      rows.length,
      (i) => DataRow(
        color: rows[i].color,
        onSelectChanged: rows[i].onSelectChanged,
        cells: <DataCell>[
          DataCell(reportStyledTableCell('${i + 1}', width: 40)),
          ...rows[i].cells,
        ],
      ),
    );

    return ReportTableSection(
      title: title,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          showCheckboxColumn: false,
          columns: indexedColumns,
          rows: indexedRows,
          emptyMessage: emptyMessage,
        ),
      ),
    );
  }
}
