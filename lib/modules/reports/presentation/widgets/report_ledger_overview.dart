import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class ReportLedgerOverview extends StatelessWidget {
  const ReportLedgerOverview({
    super.key,
    required this.title,
    required this.tableTitle,
    required this.partyHeader,
    required this.openLabel,
    required this.summaries,
    required this.displayName,
    required this.onOpenLedger,
  });

  final String title;
  final String tableTitle;
  final String partyHeader;
  final String openLabel;
  final List<PartySummaryCardEntity> summaries;
  final String Function(String name) displayName;
  final ValueChanged<PartySummaryCardEntity> onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final sorted = List<PartySummaryCardEntity>.of(summaries)
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final totalOutstanding =
        sorted.fold<double>(0, (sum, row) => sum + row.outstanding);
    final withBalance = sorted.where((row) => row.outstanding > 0.009).length;
    final layout = reportTableLayoutFor(context);
    final semantic = Theme.of(context).semantic;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Accounts',
                value: sorted.length.toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'With balance',
                value: withBalance.toString(),
                color: semantic.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ReportSummaryCardWidget(
                label: 'Total outstanding',
                value: FormattingHelpers.currencyPkr(totalOutstanding),
                color: totalOutstanding > 0 ? semantic.warning : semantic.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ReportTableSection(
            title: tableTitle,
            subtitle: title,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Fixed columns: # (48) + Outstanding (160) + Last activity
                // (150) + Open (96). Let the party name column flex to fill the
                // remaining width so the table spans the card instead of
                // floating as a narrow block. A safety buffer covers the table's
                // horizontal margins, column spacing and scrollbar so we never
                // overflow into a horizontal scrollbar.
                const fixedColumnsWidth = 48 + 160 + 150 + 96;
                final buffer = 48 + (4 * layout.columnSpacing) + 80;
                final double partyWidth =
                    (constraints.maxWidth - fixedColumnsWidth - buffer)
                        .clamp(240.0, 640.0)
                        .toDouble();
                return AppDataTable(
                  showCheckboxColumn: false,
                  emptyMessage: 'No ledger records found.',
                  columnSpacing: layout.columnSpacing,
                  dataRowMinHeight: layout.dataRowMinHeight,
                  dataRowMaxHeight: layout.dataRowMaxHeight,
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
                        partyHeader,
                        width: partyWidth,
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: reportStyledTableHeaderCell(
                        context,
                        'Outstanding (PKR)',
                        width: 160,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataColumn(
                      label: reportStyledTableHeaderCell(
                        context,
                        'Last Activity',
                        width: 150,
                      ),
                    ),
                    DataColumn(
                      label: reportStyledTableHeaderCell(
                        context,
                        'Open',
                        width: 96,
                      ),
                    ),
                  ],
                  rows: sorted.asMap().entries.map((entry) {
                    final summary = entry.value;
                    void openAccount() => onOpenLedger(summary);
                    final lastActivity = summary.lastActivityAt;
                    return DataRow(
                      onSelectChanged: (selected) {
                        if (selected != true) {
                          return;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          openAccount();
                        });
                      },
                      cells: <DataCell>[
                        DataCell(
                          reportStyledTableCell(
                            '${entry.key + 1}',
                            width: 48,
                          ),
                        ),
                        DataCell(
                          reportStyledTableCell(
                            displayName(summary.partyName),
                            width: partyWidth,
                          ),
                        ),
                        DataCell(
                          reportSemanticPill(
                            context,
                            FormattingHelpers.decimal(summary.outstanding),
                            summary.outstanding > 0.009
                                ? ReportPillIntent.warning
                                : ReportPillIntent.success,
                            width: 160,
                            alignEnd: true,
                          ),
                        ),
                        DataCell(
                          reportStyledTableCell(
                            lastActivity == null
                                ? '-'
                                : FormattingHelpers.dateYmd(lastActivity),
                            width: 150,
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 96,
                            child: IconButton.filledTonal(
                              tooltip: openLabel,
                              onPressed: openAccount,
                              icon: const Icon(Icons.chevron_right, size: 18),
                              visualDensity: VisualDensity.compact,
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
  }
}
