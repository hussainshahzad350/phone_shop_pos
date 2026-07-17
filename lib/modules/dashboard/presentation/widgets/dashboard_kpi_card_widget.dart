import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';

class DashboardKpiCardWidget extends StatelessWidget {
  const DashboardKpiCardWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.alert = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Renders the card with a warm warning tint (used by Low Stock when
  /// items need attention), mirroring the v2 mockup's alert card.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          // Tinted icon chip per the v2 mockup's KPI card anatomy.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.mdRadius,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      color: alert
          ? Color.alphaBlend(
              semantic.warningContainer.withValues(alpha: 0.35),
              theme.colorScheme.surface,
            )
          : null,
      shape: alert
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.mdRadius,
              side: BorderSide(
                color: semantic.warning.withValues(alpha: 0.45),
              ),
            )
          : null,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadii.mdRadius,
              child: content,
            )
          : content,
    );
  }
}
