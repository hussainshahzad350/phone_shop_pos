import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class ProfitTab extends ConsumerWidget {
  const ProfitTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(profitReportProvider);
    final rowsAsync = ref.watch(profitReportRowsProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

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
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Cost',
                  value: FormattingHelpers.currencyPkr(report.totalCost),
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Profit',
                  value: FormattingHelpers.currencyPkr(report.totalProfit),
                  color: report.totalProfit >= 0 ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Margin',
                  value: '${FormattingHelpers.decimal(report.marginPercent)}%',
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _TabErrorView(
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

              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: reportSectionTitle('Profit by Day')),
                          ReportExportActionWidget(
                            title: 'Profit Report',
                            fileBaseName: 'profit_report',
                            headers: headers,
                            rows: exportRows,
                            csvExportService: csvService,
                            printableReportService: printableService,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AppDataTable(
                          columnSpacing: layout.columnSpacing,
                          dataRowMinHeight: layout.dataRowMinHeight,
                          dataRowMaxHeight: layout.dataRowMaxHeight,
                          showCheckboxColumn: false,
                          emptyMessage: 'No profit rows found.',
                          columns: <DataColumn>[
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Date',
                                    width: 110)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Phones Sold',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Accessories Sold',
                                    width: 140)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Revenue (PKR)',
                                    width: 130)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Cost (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Profit (PKR)',
                                    width: 120)),
                            DataColumn(
                                label: reportStyledTableHeaderCell(
                                    context, 'Margin %',
                                    width: 90)),
                          ],
                          rows: rows.map((r) {
                            final isNegative = r.totalProfit < 0;
                            final colorScheme = Theme.of(context).colorScheme;
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(
                                    reportStyledTableCell(r.day, width: 110)),
                                DataCell(reportStyledTableCell(
                                    r.phonesSold.toString(),
                                    width: 120)),
                                DataCell(reportStyledTableCell(
                                    r.accessoriesSold.toString(),
                                    width: 140)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalRevenue),
                                    width: 130)),
                                DataCell(reportStyledTableCell(
                                    FormattingHelpers.decimal(r.totalCost),
                                    width: 120)),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: reportStyledStatusCell(
                                        context,
                                        FormattingHelpers.decimal(
                                            r.totalProfit),
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
                                DataCell(reportStyledTableCell(
                                    '${r.marginPercent.toStringAsFixed(1)}%',
                                    width: 90)),
                              ],
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _TabErrorView(
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

class _TabErrorView extends StatelessWidget {
  const _TabErrorView({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final details = error is AppError ? (error as AppError).message : '$error';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(message),
          const SizedBox(height: 6),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
