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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              selectedDealerId != null ? 'No issues for this dealer' : 'No dealer issues found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (selectedDealerId == null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Select a dealer to view issues',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Issue ID')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('IMEIs')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: issues.map((issue) => DataRow(cells: <DataCell>[
              DataCell(Text(issue.issueId.substring(0, 8))),
              DataCell(Text(FormattingHelpers.dateYmd(issue.issueDate))),
              DataCell(Text(issue.imeiList.join(', '))),
              DataCell(_buildStatusChip(context, issue)),
              DataCell(_buildActions(context, ref, issue)),
            ])).toList(growable: false),
          ),
        ),
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