import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _QuickActionButton(
              label: 'Sale',
              icon: Icons.point_of_sale_outlined,
              color: Colors.green,
              onTap: () => context.go('/sales'),
            ),
            _QuickActionButton(
              label: 'Purchase',
              icon: Icons.shopping_cart_outlined,
              color: Colors.blue,
              onTap: () => context.go('/purchases'),
            ),
            _QuickActionButton(
              label: 'Inventory',
              icon: Icons.inventory_2_outlined,
              color: Colors.indigo,
              onTap: () => context.go('/inventory'),
            ),
            _QuickActionButton(
              label: 'Audit',
              icon: Icons.search,
              color: Colors.orange,
              onTap: () => context.go('/inventory/audit'),
            ),
            if (AppRuntimeConfig.showRepairModule)
              _QuickActionButton(
                label: 'Repair',
                icon: Icons.build_outlined,
                color: Colors.red,
                onTap: () => context.go('/repairing'),
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
