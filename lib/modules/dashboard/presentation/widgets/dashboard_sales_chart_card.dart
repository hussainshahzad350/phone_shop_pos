import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/daily_sales_point_entity.dart';

/// "Sales — last 7 days" bar chart card. Pure-widget bars (no chart package):
/// each day renders weekday, a bar scaled against the week's maximum, and the
/// date. The current day's bar uses the primary color; earlier days a muted
/// tint.
class DashboardSalesChartCard extends StatelessWidget {
  const DashboardSalesChartCard({super.key, required this.points});

  final List<DailySalesPointEntity> points;

  static const List<String> _weekdayShort = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _monthShort = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTotal = points.fold<double>(
      0,
      (max, p) => p.total > max ? p.total : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sales — last 7 days',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No sales data yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = 0; i < points.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _DayBar(
                              point: points[i],
                              // Keep a sliver of bar visible on zero-sales
                              // days so the axis still reads as 7 columns.
                              heightFactor: maxTotal <= 0
                                  ? 0.02
                                  : (points[i].total / maxTotal)
                                      .clamp(0.02, 1.0),
                              isCurrent: i == points.length - 1,
                              weekdayLabel:
                                  _weekdayShort[points[i].day.weekday - 1],
                              dateLabel:
                                  '${points[i].day.day} ${_monthShort[points[i].day.month - 1]}',
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.point,
    required this.heightFactor,
    required this.isCurrent,
    required this.weekdayLabel,
    required this.dateLabel,
  });

  final DailySalesPointEntity point;
  final double heightFactor;
  final bool isCurrent;
  final String weekdayLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = isCurrent
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.28);

    return Tooltip(
      message: FormattingHelpers.currencyPkr(point.total),
      child: Column(
        children: <Widget>[
          Text(
            weekdayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 34,
                    minHeight: 3,
                  ),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.xs),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
