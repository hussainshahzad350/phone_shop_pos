import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PurchaseHistoryTab extends ConsumerWidget {
  const PurchaseHistoryTab({
    super.key,
    required this.onOpenPurchaseDetail,
  });

  final Future<void> Function(String purchaseId) onOpenPurchaseDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(purchaseHistoryRowsProvider);

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Supplier',
                    ),
                    onChanged: (value) => ref
                        .read(purchaseHistorySupplierQueryProvider.notifier)
                        .state = value,
                  ),
                ),
                ReportDateFilterButton(
                  icon: Icons.calendar_today,
                  emptyLabel: 'Start Date',
                  selectedDate: ref.watch(purchaseHistoryStartDateProvider),
                  initialDate:
                      ref.read(purchaseHistoryStartDateProvider) ?? DateTime.now(),
                  onPicked: (picked) {
                    ref.read(purchaseHistoryStartDateProvider.notifier).state =
                        picked;
                  },
                ),
                ReportDateFilterButton(
                  icon: Icons.event,
                  emptyLabel: 'End Date',
                  selectedDate: ref.watch(purchaseHistoryEndDateProvider),
                  initialDate:
                      ref.read(purchaseHistoryEndDateProvider) ?? DateTime.now(),
                  onPicked: (picked) {
                    ref.read(purchaseHistoryEndDateProvider.notifier).state =
                        picked;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rowsAsync.when(
            data: (rows) {
              final summary = ref.watch(purchaseHistoryPageSummaryProvider);
              final layout = reportTableLayoutFor(context);
              final semantic = Theme.of(context).semantic;

              return Column(
                children: <Widget>[
                  ReportSummaryRow(
                    children: <Widget>[
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Purchases (page)',
                          value: summary.totalPurchases.toString(),
                        ),
                      ),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Total (page)',
                          value: FormattingHelpers.currencyPkr(summary.sumTotal),
                          color: semantic.info,
                        ),
                      ),
                      Expanded(
                        child: ReportSummaryCardWidget(
                          label: 'Balance (page)',
                          value: FormattingHelpers.currencyPkr(
                            summary.sumBalance,
                          ),
                          color: summary.sumBalance > 0
                              ? semantic.warning
                              : semantic.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReportTableSection(
                      title: 'Purchase History',
                      child: AppDataTable(
                        columnSpacing: layout.columnSpacing,
                        dataRowMinHeight: layout.dataRowMinHeight,
                        dataRowMaxHeight: layout.dataRowMaxHeight,
                        showCheckboxColumn: false,
                        columns: <DataColumn>[
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              '#',
                              width: 48,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Date',
                              width: 110,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Supplier / Seller',
                              width: 220,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Invoice',
                              width: 130,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Total (PKR)',
                              width: 120,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Paid (PKR)',
                              width: 120,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Balance (PKR)',
                              width: 130,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Actions',
                              width: 90,
                            ),
                          ),
                        ],
                        rows: rows.asMap().entries.map((entry) {
                          final row = entry.value;
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(
                                reportStyledTableCell(
                                  '${entry.key + 1}',
                                  width: 48,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.dateYmd(row.purchaseDate),
                                  width: 110,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  row.supplierName,
                                  subtitle: row.sellerName,
                                  width: 220,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  row.invoiceNumber ?? '-',
                                  width: 130,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.decimal(row.total),
                                  width: 120,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.decimal(row.paidAmount),
                                  width: 120,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.decimal(row.remainingBalance),
                                  width: 130,
                                ),
                              ),
                              DataCell(
                                IconButton.filledTonal(
                                  tooltip: 'Open',
                                  onPressed: () => onOpenPurchaseDetail(
                                    row.purchaseId,
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  visualDensity: VisualDensity.compact,
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
            error: (error, __) => _TabErrorView(
              message: 'Failed to load purchase history.',
              error: error,
              onRetry: () => ref.invalidate(purchaseHistoryRowsProvider),
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
    final description = error is AppError
        ? error.toString()
        : 'Unexpected error: ${error.toString()}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
