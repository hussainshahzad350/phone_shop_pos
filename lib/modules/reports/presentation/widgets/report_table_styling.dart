import 'package:flutter/material.dart';

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
    if (width >= 1600) {
      return const ReportTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
      );
    }
    if (width >= 1220) {
      return const ReportTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
      );
    }
    return const ReportTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
    );
  }
}

ReportTableLayout reportTableLayoutFor(BuildContext context) {
  return ReportTableLayout.fromWidth(MediaQuery.sizeOf(context).width);
}

/// Section title style matching Daily Sales tab.
const TextStyle reportSectionTitleStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 16,
);

Widget reportSectionTitle(String title) {
  return Text(title, style: reportSectionTitleStyle);
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
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
