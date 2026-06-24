import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/dealer_issue_mark_sold_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class DealerIssuesTab extends ConsumerStatefulWidget {
  const DealerIssuesTab({super.key});

  @override
  ConsumerState<DealerIssuesTab> createState() => _DealerIssuesTabState();
}

class _DealerIssuesTabState extends ConsumerState<DealerIssuesTab> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dealerIssueStateProvider.notifier).loadIssues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dealerIssueStateProvider);

    if (state.isLoading && state.issues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final issues = state.issues;
    final filtered = _applyFilter(issues);

    final activeCount = issues
        .where((i) => !i.soldStatus && !i.returnStatus && !i.convertedToSale)
        .length;
    final soldCount = issues.where((i) => i.soldStatus).length;
    final returnedCount = issues.where((i) => i.returnStatus).length;

    final layout = reportTableLayoutFor(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Total Issues',
                  value: issues.length.toString(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Active',
                  value: activeCount.toString(),
                  color: Theme.of(context).semantic.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Sold',
                  value: soldCount.toString(),
                  color: Theme.of(context).semantic.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ReportSummaryCardWidget(
                  label: 'Returned',
                  value: returnedCount.toString(),
                  color: Theme.of(context).semantic.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  FilterChip(
                    label: const Text('All'),
                    selected: _statusFilter == 'all',
                    onSelected: (_) => setState(() => _statusFilter = 'all'),
                  ),
                  FilterChip(
                    label: const Text('Active'),
                    selected: _statusFilter == 'issued',
                    onSelected: (_) =>
                        setState(() => _statusFilter = 'issued'),
                  ),
                  FilterChip(
                    label: const Text('Sold'),
                    selected: _statusFilter == 'sold',
                    onSelected: (_) =>
                        setState(() => _statusFilter = 'sold'),
                  ),
                  FilterChip(
                    label: const Text('Returned'),
                    selected: _statusFilter == 'returned',
                    onSelected: (_) =>
                        setState(() => _statusFilter = 'returned'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  reportSectionTitle(context, 'Dealer Issues'),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  AppDataTable(
                    columnSpacing: layout.columnSpacing,
                    dataRowMinHeight: layout.dataRowMinHeight,
                    dataRowMaxHeight: layout.dataRowMaxHeight,
                    showCheckboxColumn: false,
                    emptyMessage: 'No dealer issues found.',
                    columns: <DataColumn>[
                      DataColumn(
                          label: reportStyledTableHeaderCell(context, '#',
                              width: 40)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(context, 'Date',
                              width: 100)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(
                              context, 'Issue ID',
                              width: 100)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(
                              context, 'Items',
                              width: 60)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(
                              context, 'Status',
                              width: 90)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(
                              context, 'Invoice',
                              width: 160)),
                      DataColumn(
                          label: reportStyledTableHeaderCell(
                              context, 'Actions',
                              width: 80)),
                    ],
                    rows: List<DataRow>.generate(
                      filtered.length,
                      (i) {
                        final issue = filtered[i];
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(reportStyledTableCell('${i + 1}',
                                width: 40)),
                            DataCell(reportStyledTableCell(
                                FormattingHelpers.dateYmd(issue.issueDate),
                                width: 100)),
                            DataCell(reportStyledTableCell(
                                issue.issueId.substring(0, 8),
                                width: 100)),
                            DataCell(reportStyledTableCell(
                                issue.imeiList.length.toString(),
                                width: 60)),
                            DataCell(SizedBox(
                              width: 90,
                              child: AppStatusBadge(
                                label: issue.statusText,
                                color: _statusColor(
                                    context, issue.statusColor),
                              ),
                            )),
                            DataCell(reportStyledTableCell(
                                issue.saleInvoiceId ?? '–',
                                width: 160)),
                            DataCell(SizedBox(
                              width: 80,
                              child: issue.canBeConverted
                                  ? IconButton(
                                      icon: const Icon(Icons.sell_outlined,
                                          size: 18),
                                      tooltip: 'Mark as Sold',
                                      onPressed: () =>
                                          _showMarkSoldDialog(context, issue),
                                    )
                                  : const SizedBox.shrink(),
                            )),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DealerIssueEntity> _applyFilter(List<DealerIssueEntity> issues) {
    switch (_statusFilter) {
      case 'issued':
        return issues
            .where(
                (i) => !i.soldStatus && !i.returnStatus && !i.convertedToSale)
            .toList(growable: false);
      case 'sold':
        return issues
            .where((i) => i.soldStatus)
            .toList(growable: false);
      case 'returned':
        return issues
            .where((i) => i.returnStatus)
            .toList(growable: false);
      default:
        return issues;
    }
  }

  void _showMarkSoldDialog(BuildContext context, DealerIssueEntity issue) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => DealerIssueMarkSoldDialog(issue: issue),
    );
  }

  Color _statusColor(BuildContext context, String colorString) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    switch (colorString) {
      case 'green':
        return semantic.success;
      case 'blue':
        return semantic.info;
      case 'amber':
        return semantic.warning;
      case 'purple':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
