import 'package:flutter/material.dart';

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

    return SingleChildScrollView(
      child: DataTable(
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
      ),
    );
  }
}
