import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';

/// Warning-toned "Low Stock" card with per-item Reorder shortcuts that jump
/// to the Purchases screen.
class DashboardLowStockCard extends StatelessWidget {
  const DashboardLowStockCard({super.key, required this.rows});

  final List<DashboardLowStockEntity> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;

    return Card(
      color: Color.alphaBlend(
        semantic.warningContainer.withValues(alpha: 0.35),
        theme.colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_amber, size: 16, color: semantic.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Low Stock',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: semantic.warning,
                    ),
                  ),
                ),
                if (rows.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: semantic.warning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${rows.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: semantic.onWarning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No low stock alerts.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: semantic.warning.withValues(alpha: 0.18),
                      ),
                      itemBuilder: (context, index) =>
                          _LowStockRow(row: rows[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.row});

  final DashboardLowStockEntity row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${row.quantity} left · min ${row.minQuantity}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go('/purchases'),
            style: OutlinedButton.styleFrom(
              foregroundColor: semantic.warning,
              side: BorderSide(
                color: semantic.warning.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}
