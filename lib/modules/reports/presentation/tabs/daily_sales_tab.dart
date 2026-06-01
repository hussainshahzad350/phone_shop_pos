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

class DailySalesTab extends ConsumerWidget {
  const DailySalesTab({
    super.key,
    required this.onOpenInvoice,
    required this.onReprint,
  });

  final Future<void> Function(String saleId) onOpenInvoice;
  final Future<void> Function(String jobId) onReprint;

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
    final totalInvoices = detailRows.length;
    final totalDays = detailRows
        .map((row) => '${row.saleDate.year}-${row.saleDate.month}-${row.saleDate.day}')
        .toSet()
        .length;
    final totalCustomers = detailRows
        .map((row) => row.customerName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;
    final sumTotal = detailRows.fold<double>(0, (sum, row) => sum + row.total);
    final sumPaid = detailRows.fold<double>(0, (sum, row) => sum + row.paidAmount);
    final sumBalance = detailRows.fold<double>(0, (sum, row) => sum + row.balance);

    final detailExportRows = detailRows
        .map(
          (row) => <String>[
            row.invoiceNumber,
            FormattingHelpers.dateYmd(row.saleDate),
            row.customerName,
            FormattingHelpers.decimal(row.total),
            FormattingHelpers.decimal(row.paidAmount),
            FormattingHelpers.decimal(row.balance),
            row.paymentMethod ?? '-',
            row.status,
          ],
        )
        .toList();

    final layout = reportTableLayoutFor(context);

    DataRow totalsRow() {
      final style = const TextStyle(fontWeight: FontWeight.bold);
      return DataRow(
        color: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primaryContainer.withAlpha(76),
        ),
        cells: <DataCell>[
          DataCell(Text('TOTAL', style: style)),
          DataCell(Text('Days: $totalDays', style: style)),
          DataCell(Text('Cust: $totalCustomers', style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumTotal), style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumPaid), style: style)),
          DataCell(Text(FormattingHelpers.decimal(sumBalance), style: style)),
          DataCell(Text('Inv: $totalInvoices', style: style)),
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
                value: FormattingHelpers.currencyPkr(sumTotal),
              ),
            ),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Invoices (page)',
                value: totalInvoices.toString(),
                color: Colors.indigo,
              ),
            ),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Balance (page)',
                value: FormattingHelpers.currencyPkr(sumBalance),
                color: sumBalance > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: reportSectionTitle('Sales Details')),
                      ReportExportActionWidget(
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
                      columns: <DataColumn>[
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
                        ...detailRows.map(
                          (row) => DataRow(
                            cells: <DataCell>[
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
                                  child: Row(
                                    children: <Widget>[
                                      IconButton.filledTonal(
                                        tooltip: 'Open',
                                        onPressed: () => onOpenInvoice(row.saleId),
                                        icon: const Icon(Icons.open_in_new, size: _actionIconSize),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      if (row.printJobId != null) ...<Widget>[
                                        const SizedBox(width: 6),
                                        IconButton.filledTonal(
                                          tooltip: 'Reprint',
                                          onPressed: () => onReprint(row.printJobId!),
                                          icon: const Icon(Icons.print_outlined, size: _actionIconSize),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (detailRows.isNotEmpty) totalsRow(),
                      ],
                    ),
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
