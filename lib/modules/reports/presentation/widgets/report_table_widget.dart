import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';

const int _kReportPaginateThreshold = 200;

class ReportTableColumn {
  const ReportTableColumn({required this.label});

  final String label;
}

class ReportTableWidget extends StatelessWidget {
  const ReportTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No data found.',
    this.highlightedRowIndexes = const <int>{},
  });

  final List<ReportTableColumn> columns;
  final List<List<String>> rows;
  final String emptyMessage;
  final Set<int> highlightedRowIndexes;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    final layout =
        _ReportTableLayout.fromWidth(MediaQuery.sizeOf(context).width);

    return AppDataTable(
      rowsPerPage: 50,
      paginateThreshold: _kReportPaginateThreshold,
      columnSpacing: layout.columnSpacing,
      dataRowMinHeight: layout.dataRowMinHeight,
      dataRowMaxHeight: layout.dataRowMaxHeight,
      showCheckboxColumn: false,
      columns: columns
          .map((col) => DataColumn(label: Text(col.label)))
          .toList(growable: false),
      rows: rows.asMap().entries.map(
        (entry) {
          final index = entry.key;
          final row = entry.value;
          final isHighlighted = highlightedRowIndexes.contains(index);
          final textStyle = isHighlighted
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null;
          return DataRow(
            color: isHighlighted
                ? WidgetStatePropertyAll<Color?>(
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                  )
                : null,
            cells: row
                .map((cell) => DataCell(Text(cell, style: textStyle)))
                .toList(growable: false),
          );
        },
      ).toList(growable: false),
    );
  }
}

class _ReportTableLayout {
  const _ReportTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  factory _ReportTableLayout.fromWidth(double width) {
    final m = ResponsiveTableLayout.fromWidth(width);
    return _ReportTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
    );
  }
}
