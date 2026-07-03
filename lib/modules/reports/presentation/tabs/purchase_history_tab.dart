import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_date_filter_button.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_row.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_tab_error_view.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PurchaseHistoryTab extends ConsumerWidget {
  const PurchaseHistoryTab({
    super.key,
    required this.onOpenPurchaseDetail,
    required this.onCancelPurchase,
  });

  final Future<void> Function(String purchaseId) onOpenPurchaseDetail;
  final Future<void> Function(String purchaseId, String status)
      onCancelPurchase;

  static const double _actionIconSize = 18;

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
                      subtitle:
                          'Purchases received with supplier payment status.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Flex the Supplier column so the table fills the card
                          // width instead of floating as a narrow block.
                          const fixedColumnsWidth = 48 +
                              130 +
                              110 +
                              120 +
                              120 +
                              130 +
                              100 +
                              110 +
                              132;
                          final buffer = 48 + (9 * layout.columnSpacing) + 80;
                          final double supplierWidth =
                              (constraints.maxWidth - fixedColumnsWidth - buffer)
                                  .clamp(200.0, 520.0)
                                  .toDouble();
                          return AppDataTable(
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
                              'Invoice',
                              width: 130,
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
                              width: supplierWidth,
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: reportStyledTableHeaderCell(
                              context,
                              'Total (PKR)',
                              width: 120,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: reportStyledTableHeaderCell(
                              context,
                              'Paid (PKR)',
                              width: 120,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: reportStyledTableHeaderCell(
                              context,
                              'Balance (PKR)',
                              width: 130,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Payment',
                              width: 100,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Status',
                              width: 110,
                            ),
                          ),
                          DataColumn(
                            label: reportStyledTableHeaderCell(
                              context,
                              'Actions',
                              width: 132,
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
                                  row.invoiceNumber ?? '-',
                                  width: 130,
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
                                  width: supplierWidth,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.decimal(row.total),
                                  width: 120,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  FormattingHelpers.decimal(row.paidAmount),
                                  width: 120,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              DataCell(
                                reportSemanticPill(
                                  context,
                                  FormattingHelpers.decimal(
                                      row.remainingBalance),
                                  row.remainingBalance > 0.009
                                      ? ReportPillIntent.warning
                                      : ReportPillIntent.success,
                                  width: 130,
                                  alignEnd: true,
                                ),
                              ),
                              DataCell(
                                reportStyledTableCell(
                                  _paymentMethodLabel(row.paymentMethod),
                                  width: 100,
                                ),
                              ),
                              DataCell(
                                reportStatusPill(
                                  context,
                                  row.paymentStatus,
                                  width: 110,
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 132,
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    icon: const Icon(Icons.more_vert,
                                        size: _actionIconSize),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'view':
                                          onOpenPurchaseDetail(row.purchaseId);
                                        case 'cancel':
                                          onCancelPurchase(
                                              row.purchaseId, row.status);
                                      }
                                    },
                                    itemBuilder: (context) =>
                                        <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'view',
                                        child: Row(
                                          children: <Widget>[
                                            Icon(Icons.open_in_new, size: 16),
                                            SizedBox(width: 8),
                                            Text('View Purchase'),
                                          ],
                                        ),
                                      ),
                                      if (!row.isVoid)
                                        PopupMenuItem<String>(
                                          value: 'cancel',
                                          child: Row(
                                            children: <Widget>[
                                              Icon(
                                                Icons.cancel_outlined,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Cancel Purchase',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error,
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
                        }).toList(growable: false),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => ReportTabErrorView(
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

String _paymentMethodLabel(String? paymentMethod) {
  final normalized = PaymentMethod.normalizeNullable(paymentMethod);
  return normalized == null
      ? '-'
      : PaymentMethod.labels[normalized] ?? normalized;
}
