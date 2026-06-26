import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/kpi_card_config.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/kpi_preferences_provider.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

Future<void> showKpiCustomizeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _KpiCustomizeDialog(),
  );
}

class _KpiCustomizeDialog extends ConsumerWidget {
  const _KpiCustomizeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(kpiPreferencesProvider);
    final notifier = ref.read(kpiPreferencesProvider.notifier);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.tune, size: 20),
          SizedBox(width: 8),
          Text('Customize KPI Cards'),
        ],
      ),
      contentPadding: const EdgeInsets.only(top: AppSpacing.md),
      content: SizedBox(
        width: 380,
        child: prefsAsync.when(
          loading: () => const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox(
              height: 200,
              child: Center(child: Text('Failed to load preferences.'))),
          data: (configs) {
            final visibleCount = configs.where((c) => c.visible).length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Drag to reorder. Toggle to show or hide. Minimum 2 cards required.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: configs.length,
                    onReorder: (oldIndex, newIndex) {
                      notifier.reorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final card = configs[index];
                      final isLastVisible = card.visible && visibleCount <= 2;
                      return _CardConfigTile(
                        key: ValueKey(card.id),
                        index: index,
                        config: card,
                        toggleDisabled: isLastVisible,
                        onToggle: () => notifier.toggleVisibility(card.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CardConfigTile extends StatelessWidget {
  const _CardConfigTile({
    super.key,
    required this.index,
    required this.config,
    required this.toggleDisabled,
    required this.onToggle,
  });

  final int index;
  final KpiCardConfig config;
  final bool toggleDisabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        _iconForCard(config.id),
        size: 20,
        color: config.visible ? theme.colorScheme.primary : muted,
      ),
      title: Text(
        config.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: config.visible ? null : muted,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Tooltip(
            message: toggleDisabled
                ? 'At least 2 cards must be visible'
                : config.visible
                    ? 'Hide this card'
                    : 'Show this card',
            child: Switch(
              value: config.visible,
              onChanged: toggleDisabled ? null : (_) => onToggle(),
            ),
          ),
          const SizedBox(width: 4),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: muted),
          ),
        ],
      ),
    );
  }

  IconData _iconForCard(String id) {
    switch (id) {
      case 'today_sales':
        return Icons.payments_outlined;
      case 'today_profit':
        return Icons.trending_up;
      case 'phones_sold_today':
        return Icons.phone_android;
      case 'accessories_sold_today':
        return Icons.cable;
      case 'low_stock_count':
        return Icons.warning_amber;
      case 'available_stock_count':
        return Icons.inventory_2_outlined;
      case 'total_stock_worth':
        return Icons.savings_outlined;
      case 'pending_balances':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }
}
