import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

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
  });

  final List<ReportTableColumn> columns;
  final List<List<String>> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(child: Text(emptyMessage));
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
      rows: rows
          .map(
            (row) => DataRow(
              cells: row
                  .map((cell) => DataCell(Text(cell)))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
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
    if (width >= 1600) {
      return const _ReportTableLayout(
        columnSpacing: 28,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
      );
    }
    if (width >= 1220) {
      return const _ReportTableLayout(
        columnSpacing: 20,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
      );
    }
    return const _ReportTableLayout(
      columnSpacing: 14,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
    );
  }
}
