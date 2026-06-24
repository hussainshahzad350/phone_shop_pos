import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

/// Card shell used on Daily Sales and aligned report tabs.
class ReportTableSection extends StatelessWidget {
  const ReportTableSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.filterBar,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? filterBar;
  final String? subtitle;

  bool _hasBoundedHeight(BoxConstraints constraints) {
    return constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boundedHeight = _hasBoundedHeight(constraints);
            final header = <Widget>[
              if (filterBar != null) ...<Widget>[
                filterBar!,
                const SizedBox(height: 8),
              ],
              Row(
                children: <Widget>[
                  Expanded(child: reportSectionTitle(context, title)),
                  if (trailing != null) trailing!,
                ],
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
            ];

            if (boundedHeight) {
              return SizedBox(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ...header,
                    Expanded(child: child),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ...header,
                child,
              ],
            );
          },
        ),
      ),
    );
  }
}
