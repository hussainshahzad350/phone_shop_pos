import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).semantic;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _QuickActionButton(
              label: 'Sale',
              icon: Icons.point_of_sale_outlined,
              color: semantic.success,
              onTap: () => context.go('/sales'),
            ),
            _QuickActionButton(
              label: 'Purchase',
              icon: Icons.shopping_cart_outlined,
              color: colorScheme.primary,
              onTap: () => context.go('/purchases'),
            ),
            _QuickActionButton(
              label: 'Inventory',
              icon: Icons.inventory_2_outlined,
              color: semantic.info,
              onTap: () => context.go('/inventory'),
            ),
            _QuickActionButton(
              label: 'Audit',
              icon: Icons.search,
              color: semantic.warning,
              onTap: () => context.go('/inventory/audit'),
            ),
            if (AppRuntimeConfig.showRepairModule)
              _QuickActionButton(
                label: 'Repair',
                icon: Icons.build_outlined,
                color: semantic.danger,
                onTap: () => context.go('/repairing'),
              ),
            if (AppRuntimeConfig.showDealerIssueModule)
              _QuickActionButton(
                label: 'Dealer',
                icon: Icons.swap_horiz_outlined,
                color: colorScheme.secondary,
                onTap: () => context.go('/dealer-issues'),
              ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: FilledButton.styleFrom(
        foregroundColor: color,
      ),
    );
  }
}
