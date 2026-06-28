import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_tab_error_view.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class ProfitTab extends ConsumerWidget {
  const ProfitTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(profitReportProvider);
    final rowsAsync = ref.watch(profitReportRowsProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);
    final theme = Theme.of(context);
    final semantic = theme.semantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        summaryAsync.when(
          data: (report) => ReportSummaryRow(
            children: <Widget>[
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Revenue',
                  value: FormattingHelpers.currencyPkr(report.totalRevenue),
                  color: semantic.info,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Cost',
                  value: FormattingHelpers.currencyPkr(report.totalCost),
                  color: semantic.warning,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Gross Profit',
                  value: FormattingHelpers.currencyPkr(report.grossProfit),
                  color: report.grossProfit >= 0
                      ? semantic.success
                      : semantic.danger,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Expenses',
                  value: FormattingHelpers.currencyPkr(report.totalExpenses),
                  color: semantic.warning,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Net Profit',
                  value: FormattingHelpers.currencyPkr(report.netProfit),
                  color:
                      report.netProfit >= 0 ? semantic.success : semantic.danger,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Margin',
                  value: '${FormattingHelpers.decimal(report.marginPercent)}%',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ReportTabErrorView(
            message: 'Failed to load profit summary.',
            error: error,
            onRetry: () => ref.invalidate(profitReportProvider),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              const headers = <String>[
                'Date',
                'Phones Sold',
                'Accessories Sold',
                'Revenue (PKR)',
                'Cost (PKR)',
                'Profit (PKR)',
                'Margin %',
              ];
              final exportRows = ref.watch(profitExportRowsProvider);
              final layout = reportTableLayoutFor(context);

              return ReportTableSection(
                title: 'Profit by Day',
                subtitle: 'Daily revenue, cost and profit margin breakdown.',
                trailing: ReportExportActionWidget(
                  title: 'Profit Report',
                  fileBaseName: 'profit_report',
                  headers: headers,
                  rows: exportRows,
                  csvExportService: csvService,
                  printableReportService: printableService,
                ),
                child: AppDataTable(
                          columnSpacing: layout.columnSpacing,
                          dataRowMinHeight: layout.dataRowMinHeight,
                          dataRowMaxHeight: layout.dataRowMaxHeight,
                          showCheckboxColumn: false,
                          emptyMessage: 'No profit rows found.',
                          columns: <DataColumn>[
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, '#',
                                    width: 48)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Date',
                                    width: 110)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Phones Sold',
                                    width: 120, textAlign: TextAlign.right)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Accessories Sold',
                                    width: 140, textAlign: TextAlign.right)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Revenue (PKR)',
                                    width: 130, textAlign: TextAlign.right)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Cost (PKR)',
                                    width: 120, textAlign: TextAlign.right)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Profit (PKR)',
                                    width: 120, textAlign: TextAlign.right)),
                            DataColumn(
                                numeric: true,
                                label: reportStyledTableHeaderCell(
                                    context, 'Margin %',
                                    width: 90, textAlign: TextAlign.right)),
                          ],
                          rows: rows.asMap().entries.map((entry) {
                            final r = entry.value;
                            final isNegative = r.totalProfit < 0;
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(reportStyledTableCell(
                                    '${entry.key + 1}', width: 48)),
                                DataCell(
                                    reportStyledTableCell(r.day, width: 110)),
                                DataCell(reportStyledTableCell(
                                    r.phonesSold.toString(),
                                    width: 120, textAlign: TextAlign.right)),
                                DataCell(reportStyledTableCell(
                                    r.accessoriesSold.toString(),
                                    width: 140, textAlign: TextAlign.right)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalRevenue),
                                    width: 130, textAlign: TextAlign.right)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalCost),
                                    width: 120, textAlign: TextAlign.right)),
                                DataCell(
                                  reportSemanticPill(
                                    context,
                                    FormattingHelpers.decimal(r.totalProfit),
                                    isNegative
                                        ? ReportPillIntent.danger
                                        : ReportPillIntent.success,
                                    width: 120,
                                    alignEnd: true,
                                  ),
                                ),
                                DataCell(reportStyledTableCell(
                                    '${r.marginPercent.toStringAsFixed(1)}%',
                                    width: 90, textAlign: TextAlign.right)),
                              ],
                            );
                          }).toList(growable: false),
                        ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ReportTabErrorView(
              message: 'Failed to load profit breakdown.',
              error: error,
              onRetry: () => ref.invalidate(profitReportRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}
