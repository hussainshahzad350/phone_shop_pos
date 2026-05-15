import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';

class StockTableWidget extends StatelessWidget {
  const StockTableWidget({super.key, required this.rows});

  final List<StockRowEntity> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No stock records found.'));
    }

    return AppDataTable(
      columnSpacing: 16,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 44,
      rowsPerPage: 50,
      paginateThreshold: 120,
      columns: const <DataColumn>[
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('Brand')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('IMEI / Qty')),
        DataColumn(label: Text('Status / Stock')),
        DataColumn(label: Text('Cost'), numeric: true),
        DataColumn(label: Text('Price'), numeric: true),
        DataColumn(label: Text('Location')),
      ],
      rows: rows.map(_buildRow).toList(growable: false),
    );
  }

  DataRow _buildRow(StockRowEntity row) {
    if (row.type == StockRowType.serialized) {
      return DataRow(
        cells: <DataCell>[
          const DataCell(Text('Phone')),
          DataCell(Text(row.productName)),
          DataCell(Text(row.brand ?? '')),
          DataCell(Text(row.category ?? '')),
          DataCell(
            Text(
              row.imei1 != null && row.imei1!.length > 10
                  ? '${row.imei1!.substring(0, 10)}…'
                  : (row.imei1 ?? '—'),
            ),
          ),
          DataCell(_statusBadge(row.serializedStatus)),
          DataCell(
            Text(
              row.costPrice != null
                  ? FormattingHelpers.decimal(
                      row.costPrice!,
                      fractionDigits: 0,
                    )
                  : '—',
            ),
          ),
          DataCell(
            Text(
              row.sellingPrice != null
                  ? FormattingHelpers.decimal(
                      row.sellingPrice!,
                      fractionDigits: 0,
                    )
                  : '—',
            ),
          ),
          const DataCell(Text('—')),
        ],
      );
    }

    final isLow = row.isLowStock;
    return DataRow(
      cells: <DataCell>[
        const DataCell(Text('Accessory')),
        DataCell(Text(row.productName)),
        DataCell(Text(row.brand ?? '')),
        DataCell(Text(row.category ?? '')),
        DataCell(
          Text(
            row.quantity?.toString() ?? '—',
            style: isLow
                ? const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
        ),
        DataCell(
          isLow
              ? _chipLabel('Low Stock', Colors.red)
              : _chipLabel('In Stock', Colors.green),
        ),
        DataCell(
          Text(
            row.unitCost != null
                ? FormattingHelpers.decimal(row.unitCost!, fractionDigits: 0)
                : '—',
          ),
        ),
        DataCell(
          Text(
            row.unitPrice != null
                ? FormattingHelpers.decimal(row.unitPrice!, fractionDigits: 0)
                : '—',
          ),
        ),
        DataCell(Text(row.location ?? '—')),
      ],
    );
  }

  Widget _statusBadge(SerializedStockStatus? status) {
    if (status == null) {
      return const Text('—');
    }
    Color color;
    String label;
    switch (status) {
      case SerializedStockStatus.inStock:
        color = Colors.green;
        label = 'In Stock';
        break;
      case SerializedStockStatus.sold:
        color = Colors.grey;
        label = 'Sold';
        break;
      case SerializedStockStatus.reserved:
        color = Colors.amber;
        label = 'Reserved';
        break;
      case SerializedStockStatus.returned:
        color = Colors.blue;
        label = 'Returned';
        break;
      case SerializedStockStatus.damaged:
        color = Colors.red;
        label = 'Damaged';
        break;
    }
    return _chipLabel(label, color);
  }

  Widget _chipLabel(String label, Color color) {
    return AppStatusBadge(
      label: label,
      color: color,
    );
  }
}
