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

    return AppDataTable(
      rowsPerPage: 50,
      paginateThreshold: _kReportPaginateThreshold,
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
