import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class DashboardKpiCardWidget extends StatelessWidget {
  const DashboardKpiCardWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ),
    );

    return Card(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadii.lgRadius,
              child: content,
            )
          : content,
    );
  }
}
