import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_transaction_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/dialogs/dashboard_sales_invoice_dialog.dart';

/// "Recent Transactions" feed card: sales, purchases, repairs and customer
/// payments merged newest-first. Sale rows open the invoice dialog.
class DashboardTransactionsCard extends StatelessWidget {
  const DashboardTransactionsCard({super.key, required this.transactions});

  final List<DashboardTransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelSmall,
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                      itemBuilder: (context, index) =>
                          _TransactionRow(transaction: transactions[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final DashboardTransactionEntity transaction;

  Color _dotColor(BuildContext context) {
    final semantic = Theme.of(context).semantic;
    switch (transaction.type) {
      case DashboardTransactionType.sale:
        return semantic.success;
      case DashboardTransactionType.purchase:
        return semantic.warning;
      case DashboardTransactionType.repair:
        return semantic.danger;
      case DashboardTransactionType.customerPayment:
        return semantic.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _dotColor(context);
    final sign = transaction.isOutflow ? '−' : '+';
    final amountText =
        '$sign ${FormattingHelpers.decimal(transaction.amount)}';
    final saleId = transaction.saleId;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${transaction.reference} · '
                  '${FormattingHelpers.dateYmdHm(transaction.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            amountText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );

    if (saleId == null || saleId.isEmpty) return row;
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => DashboardSalesInvoiceDialog(saleId: saleId),
      ),
      child: row,
    );
  }
}
