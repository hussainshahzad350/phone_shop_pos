import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_export_action_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class DailySalesTab extends ConsumerWidget {
  const DailySalesTab({
    super.key,
    required this.onOpenInvoice,
    required this.onReprint,
    required this.onCancelSale,
  });

  final Future<void> Function(String saleId) onOpenInvoice;
  final Future<void> Function(String jobId) onReprint;
  final Future<void> Function(String saleId, String status) onCancelSale;

  static const double _actionIconSize = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(dateRangeSalesReportProvider);
    final csvService = ref.watch(csvExportServiceProvider);
    final printableService = ref.watch(printableReportServiceProvider);

    if (detailAsync.hasError) {
      return _TabErrorView(
        message: 'Failed to load sales details report.',
        error: detailAsync.error!,
        onRetry: () => ref.invalidate(dateRangeSalesReportProvider),
      );
    }
    if (detailAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detailRows = detailAsync.value ?? const [];
    final summary = ref.watch(dailySalesPageSummaryProvider);
    final detailExportRows = ref.watch(dailySalesExportRowsProvider);

    final layout = reportTableLayoutFor(context);

    DataRow totalsRow() {
      final style = const TextStyle(fontWeight: FontWeight.bold);
      return DataRow(
        color: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primaryContainer.withAlpha(76),
        ),
        cells: <DataCell>[
          const DataCell(SizedBox(width: 48)),
          DataCell(Text('TOTAL', style: style)),
          DataCell(Text('Days: ${summary.totalDays}', style: style)),
          DataCell(Text('Cust: ${summary.totalCustomers}', style: style)),
          DataCell(
            Text(FormattingHelpers.decimal(summary.sumTotal), style: style),
          ),
          DataCell(
            Text(FormattingHelpers.decimal(summary.sumPaid), style: style),
          ),
          DataCell(
            Text(FormattingHelpers.decimal(summary.sumBalance), style: style),
          ),
          DataCell(Text('Inv: ${summary.totalInvoices}', style: style)),
          DataCell(Text('-', style: style)),
          DataCell(const SizedBox.shrink()),
        ],
      );
    }

    return Column(
      children: <Widget>[
        ReportSummaryRow(
          children: <Widget>[
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Total Sales (page)',
                value: FormattingHelpers.currencyPkr(summary.sumTotal),
              ),
            ),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Invoices (page)',
                value: summary.totalInvoices.toString(),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Balance (page)',
                value: FormattingHelpers.currencyPkr(summary.sumBalance),
                color: summary.sumBalance > 0
                    ? Theme.of(context).semantic.warning
                    : Theme.of(context).semantic.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReportTableSection(
            title: 'Sales Details',
            trailing: ReportExportActionWidget(
              title: 'Daily Sales Details Report',
              fileBaseName: 'daily_sales_details_report',
              headers: const <String>[
                'Invoice',
                'Date',
                'Customer',
                'Total (PKR)',
                'Paid (PKR)',
                'Balance (PKR)',
                'Payment',
                'Status',
              ],
              rows: detailExportRows,
              csvExportService: csvService,
              printableReportService: printableService,
            ),
            child: AppDataTable(
                      columnSpacing: layout.columnSpacing,
                      dataRowMinHeight: layout.dataRowMinHeight,
                      dataRowMaxHeight: layout.dataRowMaxHeight,
                      showCheckboxColumn: false,
                      columns: <DataColumn>[
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, '#', width: 48),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Invoice', width: 130),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Date', width: 110),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Customer', width: 220),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Total (PKR)', width: 120),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Paid (PKR)', width: 120),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Balance (PKR)', width: 130),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Payment', width: 100),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Status', width: 100),
                        ),
                        DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Actions', width: 132),
                        ),
                      ],
                      rows: <DataRow>[
                        ...detailRows.asMap().entries.map(
                          (entry) {
                            final row = entry.value;
                            return DataRow(
                            cells: <DataCell>[
                              DataCell(reportStyledTableCell('${entry.key + 1}', width: 48)),
                              DataCell(reportStyledTableCell(row.invoiceNumber, width: 130)),
                              DataCell(reportStyledTableCell(FormattingHelpers.dateYmd(row.saleDate), width: 110)),
                              DataCell(reportStyledTableCell(row.customerName, width: 220)),
                              DataCell(reportStyledTableCell(FormattingHelpers.decimal(row.total), width: 120)),
                              DataCell(reportStyledTableCell(FormattingHelpers.decimal(row.paidAmount), width: 120)),
                              DataCell(reportStyledTableCell(FormattingHelpers.decimal(row.balance), width: 130)),
                              DataCell(reportStyledTableCell(row.paymentMethod ?? '-', width: 100)),
                              DataCell(reportStyledTableCell(row.status, width: 100)),
                              DataCell(
                                SizedBox(
                                  width: 132,
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    icon: const Icon(Icons.more_vert, size: _actionIconSize),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'view':
                                          onOpenInvoice(row.saleId);
                                        case 'reprint':
                                          if (row.printJobId != null) {
                                            onReprint(row.printJobId!);
                                          }
                                        case 'cancel':
                                          onCancelSale(row.saleId, row.status);
                                      }
                                    },
                                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'view',
                                        child: Row(
                                          children: <Widget>[
                                            Icon(Icons.open_in_new, size: 16),
                                            SizedBox(width: 8),
                                            Text('View Invoice'),
                                          ],
                                        ),
                                      ),
                                      if (row.printJobId != null)
                                        const PopupMenuItem<String>(
                                          value: 'reprint',
                                          child: Row(
                                            children: <Widget>[
                                              Icon(Icons.print_outlined, size: 16),
                                              SizedBox(width: 8),
                                              Text('Reprint Receipt'),
                                            ],
                                          ),
                                        ),
                                      if (row.status != 'void')
                                        PopupMenuItem<String>(
                                          value: 'cancel',
                                          child: Row(
                                            children: <Widget>[
                                              Icon(
                                                Icons.cancel_outlined,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.error,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Cancel Sale',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                          },
                        ),
                        if (detailRows.isNotEmpty) totalsRow(),
                      ],
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
