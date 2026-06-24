import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';

/// Shared table typography and layout used across Reports tabs.
class ReportTableLayout {
  const ReportTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  factory ReportTableLayout.fromWidth(double width) {
    final m = ResponsiveTableLayout.fromWidth(width);
    return ReportTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
    );
  }
}

ReportTableLayout reportTableLayoutFor(BuildContext context) {
  return ReportTableLayout.fromWidth(MediaQuery.sizeOf(context).width);
}

Widget reportSectionTitle(BuildContext context, String title) {
  return Text(title, style: Theme.of(context).textTheme.titleLarge);
}

Widget reportStyledTableHeaderCell(
  BuildContext context,
  String label, {
  double? width,
}) {
  final theme = Theme.of(context);
  return SizedBox(
    width: width,
    child: Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    ),
  );
}

Widget reportStyledTableCell(
  String value, {
  double? width,
  TextAlign textAlign = TextAlign.left,
  String? subtitle,
}) {
  final normalizedSubtitle = subtitle?.trim();
  if (normalizedSubtitle != null && normalizedSubtitle.isNotEmpty) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: textAlign == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Seller: $normalizedSubtitle',
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
  return SizedBox(
    width: width,
    child: Text(
      value,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget reportStyledStatusCell(
  BuildContext context,
  String label,
  Color bgColor,
  Color fgColor,
) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: fgColor,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}
