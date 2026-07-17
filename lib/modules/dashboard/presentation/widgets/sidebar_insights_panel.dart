import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';

/// "This Month" top-performer indicators shown in the extended navigation
/// sidebar: top selling brand, model, customer and accessory.
class SidebarInsightsPanel extends ConsumerWidget {
  const SidebarInsightsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final insights = ref.watch(sidebarInsightsProvider).valueOrNull;
    if (insights == null || !insights.hasTopPerformers) {
      return const SizedBox.shrink();
    }

    final rows = <(_IndicatorSpec, String?)>[
      (
        _IndicatorSpec(Icons.trending_up, semantic.success,
            'Top selling brand'),
        insights.topSellingBrand,
      ),
      (
        _IndicatorSpec(Icons.phone_android, theme.colorScheme.primary,
            'Top selling model'),
        insights.topSellingModel,
      ),
      (
        _IndicatorSpec(Icons.person_outline, semantic.warning,
            'Top customer'),
        insights.topCustomer,
      ),
      (
        _IndicatorSpec(Icons.cable, semantic.danger, 'Top accessory'),
        insights.topAccessory,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'THIS MONTH',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final (spec, value) in rows)
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SidebarKpiCard(spec: spec, value: value),
              ),
        ],
      ),
    );
  }
}

/// Miniature KPI card for one sidebar indicator — same anatomy as the
/// dashboard's KPI cards (tinted icon chip, bold value, muted label) at
/// sidebar scale.
class _SidebarKpiCard extends StatelessWidget {
  const _SidebarKpiCard({required this.spec, required this.value});

  final _IndicatorSpec spec;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadii.mdRadius,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.12),
              borderRadius: AppRadii.smRadius,
            ),
            child: Icon(spec.icon, size: 16, color: spec.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorSpec {
  const _IndicatorSpec(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;
  final String label;
}

/// Compact "Today" sales/profit summary pinned to the bottom of the extended
/// navigation sidebar.
class SidebarTodaySummaryCard extends ConsumerWidget {
  const SidebarTodaySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final kpis = ref.watch(dashboardKpisProvider).valueOrNull;
    if (kpis == null) return const SizedBox.shrink();

    Widget row(String label, String value, Color valueColor) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadii.mdRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TODAY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          row(
            'Sales',
            FormattingHelpers.currencyPkr(kpis.todaySales),
            semantic.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          row(
            'Profit',
            FormattingHelpers.currencyPkr(kpis.todayProfit),
            kpis.todayProfit >= 0
                ? theme.colorScheme.onSurface
                : semantic.danger,
          ),
        ],
      ),
    );
  }
}
