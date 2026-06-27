import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/dealer_issue_mark_sold_dialog.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class DealerIssueTableWidget extends ConsumerWidget {
  const DealerIssueTableWidget({
    super.key,
    required this.issues,
    required this.isLoading,
    required this.selectedDealerId,
  });

  final List<DealerIssueEntity> issues;
  final bool isLoading;
  final String? selectedDealerId;

  // Column widths kept consistent with the app's other AppDataTable screens.
  static const double _wNum = 48;
  static const double _wIssueId = 110;
  static const double _wDate = 110;
  static const double _wImeis = 280;
  static const double _wStatus = 120;
  static const double _wActions = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppDataTable(
      showCheckboxColumn: false,
      paginateThreshold: 40,
      emptyIcon: Icons.inventory_2_outlined,
      emptyMessage: selectedDealerId != null
          ? 'No issues for this dealer.'
          : 'No dealer issues found. Select a dealer to view issues.',
      columns: <DataColumn>[
        DataColumn(label: _headerCell(context, '#', width: _wNum)),
        DataColumn(label: _headerCell(context, 'Issue ID', width: _wIssueId)),
        DataColumn(label: _headerCell(context, 'Date', width: _wDate)),
        DataColumn(label: _headerCell(context, 'IMEIs', width: _wImeis)),
        DataColumn(label: _headerCell(context, 'Status', width: _wStatus)),
        DataColumn(label: _headerCell(context, 'Actions', width: _wActions)),
      ],
      rows: issues.asMap().entries.map((entry) {
        final issue = entry.value;
        return DataRow(
          cells: <DataCell>[
            DataCell(_textCell('${entry.key + 1}', width: _wNum)),
            DataCell(_textCell(issue.issueId.substring(0, 8), width: _wIssueId)),
            DataCell(_textCell(
              FormattingHelpers.dateYmd(issue.issueDate),
              width: _wDate,
            )),
            DataCell(_textCell(
              issue.imeiList.join(', '),
              width: _wImeis,
              maxLines: 2,
            )),
            DataCell(SizedBox(
              width: _wStatus,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusChip(context, issue),
              ),
            )),
            DataCell(SizedBox(
              width: _wActions,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _buildActions(context, ref, issue),
                ),
              ),
            )),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _headerCell(BuildContext context, String label, {required double width}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _textCell(String value, {required double width, int maxLines = 1}) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, DealerIssueEntity issue) {
    final label = issue.statusText;

    return AppStatusBadge(
      label: label,
      color: _getStatusColor(context, issue.statusColor),
    );
  }

  Color _getStatusColor(BuildContext context, String colorString) {
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

  Widget _buildActions(BuildContext context, WidgetRef ref, DealerIssueEntity issue) {

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        if (issue.canBeReturned)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Mark Returned',
            onPressed: () => _showReturnDialog(context, ref, issue),
          ),
        if (issue.canBeConverted)
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            tooltip: 'Mark as Sold',
            onPressed: () => _showMarkSoldDialog(context, ref, issue),
          ),
        if (issue.canBeDeleted)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
            tooltip: 'Delete Issue',
            onPressed: () => _showDeleteDialog(context, ref, issue),
          ),
      ],
    );
  }

  void _showReturnDialog(BuildContext context, WidgetRef ref, DealerIssueEntity issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Returned'),
        content: Text('Are you sure you want to mark this issue as returned?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              ref.read(dealerIssueStateProvider.notifier).markAsReturned(issue.issueId);
            },
            child: const Text('Mark Returned'),
          ),
        ],
      ),
    );
  }

  void _showMarkSoldDialog(BuildContext context, WidgetRef ref, DealerIssueEntity issue) {
    showDialog<bool>(
      context: context,
      builder: (context) => DealerIssueMarkSoldDialog(issue: issue),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, DealerIssueEntity issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issue'),
        content: Text('Are you sure you want to delete this issue? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop(true);
              ref.read(dealerIssueStateProvider.notifier).deleteIssue(issue.issueId);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}