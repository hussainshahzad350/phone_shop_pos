import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/pending_return_entity.dart';

class AlertsSection extends StatelessWidget {
  const AlertsSection({
    super.key,
    required this.lowStockCount,
    required this.pendingReturns,
  });

  final int lowStockCount;
  final List<PendingReturnEntity> pendingReturns;

  @override
  Widget build(BuildContext context) {
    final totalAlerts = lowStockCount + pendingReturns.length;

    if (totalAlerts == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (totalAlerts > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).semantic.dangerContainer,
                      borderRadius: AppRadii.mdRadius,
                    ),
                    child: Text(
                      '$totalAlerts',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).semantic.danger,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (lowStockCount > 0) ...<Widget>[
              Text(
                'Low Stock Items',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(
                lowStockCount.clamp(0, 3),
                (index) => _AlertItem(
                  type: 'low_stock',
                  message: 'Stock running low',
                ),
              ),
              if (lowStockCount > 3)
                Text(
                  'And $lowStockCount more items...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 8),
            ],
            if (pendingReturns.isNotEmpty) ...<Widget>[
              Text(
                'Pending Returns',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...pendingReturns.take(3).map(
                (returnItem) => _AlertItem(
                  type: 'pending_return',
                  message: returnItem.invoiceNumber,
                  subtext: FormattingHelpers.dateYmdHm(returnItem.returnDate),
                ),
              ),
              if (pendingReturns.length > 3)
                Text(
                  'And ${pendingReturns.length - 3} more returns...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  const _AlertItem({
    required this.type,
    required this.message,
    this.subtext,
  });

  final String type;
  final String message;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(
            type == 'low_stock' ? Icons.warning_amber : Icons.warning,
            size: 16,
            color: Theme.of(context).semantic.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (subtext != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}