import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
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
  TextAlign textAlign = TextAlign.left,
}) {
  final theme = Theme.of(context);
  return SizedBox(
    width: width,
    child: Text(
      label,
      textAlign: textAlign,
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

/// Semantic intent for value/status pills shared across report tables.
enum ReportPillIntent { neutral, success, warning, danger, info }

/// A color-coded pill (Cash Flow "net cash" treatment) used to emphasize a
/// status or key value uniformly across report tables. Pass [width] and
/// [alignEnd] to align it inside a fixed-width numeric column.
Widget reportSemanticPill(
  BuildContext context,
  String label,
  ReportPillIntent intent, {
  double? width,
  bool alignEnd = false,
}) {
  final semantic = Theme.of(context).semantic;
  final colorScheme = Theme.of(context).colorScheme;
  late final Color bg;
  late final Color fg;
  switch (intent) {
    case ReportPillIntent.success:
      bg = semantic.successContainer;
      fg = semantic.success;
    case ReportPillIntent.warning:
      bg = semantic.warningContainer;
      fg = semantic.warning;
    case ReportPillIntent.danger:
      bg = semantic.dangerContainer;
      fg = semantic.danger;
    case ReportPillIntent.info:
      bg = semantic.infoContainer;
      fg = semantic.info;
    case ReportPillIntent.neutral:
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurfaceVariant;
  }
  final pill = reportStyledStatusCell(context, label, bg, fg);
  if (width == null) {
    return pill;
  }
  return SizedBox(
    width: width,
    child: Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: pill,
    ),
  );
}

/// Maps a sale/purchase status string to its pill intent so status columns read
/// the same everywhere (paid = success, pending = warning, etc.).
ReportPillIntent reportStatusIntent(String status) {
  switch (status.trim().toLowerCase()) {
    case 'paid':
    case 'completed':
      return ReportPillIntent.success;
    case 'pending':
    case 'partial':
      return ReportPillIntent.warning;
    case 'void':
    case 'cancelled':
    case 'canceled':
    case 'refunded':
      return ReportPillIntent.danger;
    default:
      return ReportPillIntent.neutral;
  }
}

/// Renders a status string as a uniformly colored status pill.
Widget reportStatusPill(
  BuildContext context,
  String status, {
  double? width,
}) {
  return reportSemanticPill(
    context,
    reportStatusLabel(status),
    reportStatusIntent(status),
    width: width,
  );
}

/// Human-readable status label. Void is surfaced as "Cancelled" so cancelled
/// sales/purchases read consistently across the reports tables.
String reportStatusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  switch (normalized) {
    case 'void':
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    case '':
      return '-';
    default:
      return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}
