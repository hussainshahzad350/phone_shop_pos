import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';

const int _kStockPaginateThreshold = 120;

class StockTableWidget extends StatelessWidget {
  const StockTableWidget({super.key, required this.rows});

  final List<StockRowEntity> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        message: 'No stock records found.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _StockTableLayout.fromWidth(constraints.maxWidth);
        final visibleColumns = _visibleColumns(layout);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          rowsPerPage: 50,
          paginateThreshold: _kStockPaginateThreshold,
          columns: visibleColumns
              .map((column) => _buildDataColumn(column, layout))
              .toList(growable: false),
          rows: rows
              .map((row) =>
                  _buildResponsiveRow(context, row, visibleColumns, layout))
              .toList(growable: false),
        );
      },
    );
  }

  List<_StockTableColumn> _visibleColumns(_StockTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_StockTableColumn>[
        _StockTableColumn.type,
        _StockTableColumn.product,
        _StockTableColumn.imeiOrQty,
        _StockTableColumn.statusOrStock,
        _StockTableColumn.price,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_StockTableColumn>[
        _StockTableColumn.type,
        _StockTableColumn.product,
        _StockTableColumn.brand,
        _StockTableColumn.imeiOrQty,
        _StockTableColumn.statusOrStock,
        _StockTableColumn.cost,
        _StockTableColumn.price,
      ];
    }
    return const <_StockTableColumn>[
      _StockTableColumn.type,
      _StockTableColumn.condition,
      _StockTableColumn.product,
      _StockTableColumn.brand,
      _StockTableColumn.category,
      _StockTableColumn.imeiOrQty,
      _StockTableColumn.statusOrStock,
      _StockTableColumn.cost,
      _StockTableColumn.price,
      _StockTableColumn.location,
    ];
  }

  DataColumn _buildDataColumn(
    _StockTableColumn column,
    _StockTableLayout layout,
  ) {
    final label = _columnLabel(column);
    return DataColumn(
      numeric:
          column == _StockTableColumn.cost || column == _StockTableColumn.price,
      label: _labelCell(
        label,
        width: layout.labelWidth(column),
        textAlign: (column == _StockTableColumn.cost ||
                column == _StockTableColumn.price)
            ? TextAlign.right
            : TextAlign.left,
      ),
    );
  }

  DataRow _buildResponsiveRow(
    BuildContext context,
    StockRowEntity row,
    List<_StockTableColumn> columns,
    _StockTableLayout layout,
  ) {
    return DataRow(
      cells: columns
          .map((column) => _buildDataCell(context, row, column, layout))
          .toList(growable: false),
    );
  }

  DataCell _buildDataCell(
    BuildContext context,
    StockRowEntity row,
    _StockTableColumn column,
    _StockTableLayout layout,
  ) {
    final isSerialized = row.type == StockRowType.serialized;
    switch (column) {
      case _StockTableColumn.type:
        return DataCell(
          _textCell(
            isSerialized ? 'Phone' : 'Accessory',
            width: layout.valueWidth(column),
          ),
        );
      case _StockTableColumn.condition:
        if (!isSerialized) {
          return DataCell(_textCell('—', width: layout.valueWidth(column)));
        }
        final isUsed = row.condition == SerializedStockCondition.used;
        return DataCell(
          SizedBox(
            width: layout.valueWidth(column),
            child: Align(
              alignment: Alignment.centerLeft,
              child: isUsed
                  ? _chipLabel('Used', Theme.of(context).semantic.warning)
                  : _chipLabel('New', Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      case _StockTableColumn.product:
        return DataCell(
          _textCell(
            row.productName,
            width: layout.valueWidth(column),
            maxLines: 1,
          ),
        );
      case _StockTableColumn.brand:
        return DataCell(
          _textCell(row.brand ?? '—', width: layout.valueWidth(column)),
        );
      case _StockTableColumn.category:
        return DataCell(
          _textCell(row.category ?? '—', width: layout.valueWidth(column)),
        );
      case _StockTableColumn.imeiOrQty:
        if (isSerialized) {
          return DataCell(
            _textCell(_formatImei(row.imei1), width: layout.valueWidth(column)),
          );
        }
        return DataCell(
          _textCell(
            row.quantity?.toString() ?? '—',
            width: layout.valueWidth(column),
            style: row.isLowStock
                ? TextStyle(
                    color: Theme.of(context).semantic.danger,
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
        );
      case _StockTableColumn.statusOrStock:
        if (isSerialized) {
          return DataCell(
            SizedBox(
              width: layout.valueWidth(column),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusBadge(context, row.serializedStatus),
              ),
            ),
          );
        }
        return DataCell(
          SizedBox(
            width: layout.valueWidth(column),
            child: Align(
              alignment: Alignment.centerLeft,
              child: row.isLowStock
                  ? _chipLabel('Low Stock', Theme.of(context).semantic.danger)
                  : _chipLabel('In Stock', Theme.of(context).semantic.success),
            ),
          ),
        );
      case _StockTableColumn.cost:
        return DataCell(
          _textCell(
            isSerialized
                ? (row.costPrice != null
                    ? FormattingHelpers.decimal(row.costPrice!,
                        fractionDigits: 0)
                    : '—')
                : (row.unitCost != null
                    ? FormattingHelpers.decimal(row.unitCost!,
                        fractionDigits: 0)
                    : '—'),
            width: layout.valueWidth(column),
            textAlign: TextAlign.right,
          ),
        );
      case _StockTableColumn.price:
        return DataCell(
          _textCell(
            isSerialized
                ? (row.sellingPrice != null
                    ? FormattingHelpers.decimal(row.sellingPrice!,
                        fractionDigits: 0)
                    : '—')
                : (row.unitPrice != null
                    ? FormattingHelpers.decimal(row.unitPrice!,
                        fractionDigits: 0)
                    : '—'),
            width: layout.valueWidth(column),
            textAlign: TextAlign.right,
          ),
        );
      case _StockTableColumn.location:
        return DataCell(
          _textCell(row.location ?? '—', width: layout.valueWidth(column)),
        );
    }
  }

  String _columnLabel(_StockTableColumn column) {
    switch (column) {
      case _StockTableColumn.type:
        return 'Type';
      case _StockTableColumn.condition:
        return 'Condition';
      case _StockTableColumn.product:
        return 'Product';
      case _StockTableColumn.brand:
        return 'Brand';
      case _StockTableColumn.category:
        return 'Category';
      case _StockTableColumn.imeiOrQty:
        return 'IMEI / Qty';
      case _StockTableColumn.statusOrStock:
        return 'Status / Stock';
      case _StockTableColumn.cost:
        return 'Cost';
      case _StockTableColumn.price:
        return 'Price';
      case _StockTableColumn.location:
        return 'Location';
    }
  }

  String _formatImei(String? imei) {
    if (imei == null || imei.isEmpty) {
      return '—';
    }
    if (imei.length <= 14) {
      return imei;
    }
    return '${imei.substring(0, 14)}…';
  }

  Widget _labelCell(
    String label, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: textAlign,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _textCell(
    String value, {
    required double width,
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(BuildContext context, SerializedStockStatus? status) {
    if (status == null) {
      return const Text('—');
    }
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    Color color;
    String label;
    switch (status) {
      case SerializedStockStatus.inStock:
        color = semantic.success;
        label = 'In Stock';
        break;
      case SerializedStockStatus.sold:
        color = theme.colorScheme.onSurfaceVariant;
        label = 'Sold';
        break;
      case SerializedStockStatus.reserved:
        color = semantic.warning;
        label = 'Reserved';
        break;
      case SerializedStockStatus.returned:
        color = semantic.info;
        label = 'Returned';
        break;
      case SerializedStockStatus.damaged:
        color = semantic.danger;
        label = 'Damaged';
        break;
      case SerializedStockStatus.withDealer:
        color = semantic.warning;
        label = 'With Dealer';
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

enum _StockTableColumn {
  type,
  condition,
  product,
  brand,
  category,
  imeiOrQty,
  statusOrStock,
  cost,
  price,
  location,
}

class _StockTableLayout {
  const _StockTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.showMediumColumns,
    required this.showCompactColumns,
    required this.isWideDesktop,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showMediumColumns;
  final bool showCompactColumns;
  final bool isWideDesktop;

  factory _StockTableLayout.fromWidth(double width) {
    final m = ResponsiveTableLayout.fromWidth(width);
    return _StockTableLayout(
      columnSpacing: m.columnSpacing,
      dataRowMinHeight: m.dataRowMinHeight,
      dataRowMaxHeight: m.dataRowMaxHeight,
      showMediumColumns: m.showMediumColumns,
      showCompactColumns: m.showCompactColumns,
      isWideDesktop: m.isWideDesktop,
    );
  }

  double labelWidth(_StockTableColumn column) {
    return valueWidth(column);
  }

  double valueWidth(_StockTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _StockTableColumn.type:
          return 92;
        case _StockTableColumn.condition:
          return 120;
        case _StockTableColumn.product:
          return 320;
        case _StockTableColumn.brand:
          return 180;
        case _StockTableColumn.category:
          return 170;
        case _StockTableColumn.imeiOrQty:
          return 170;
        case _StockTableColumn.statusOrStock:
          return 170;
        case _StockTableColumn.cost:
        case _StockTableColumn.price:
          return 132;
        case _StockTableColumn.location:
          return 180;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _StockTableColumn.type:
          return 88;
        case _StockTableColumn.condition:
          return 100;
        case _StockTableColumn.product:
          return 250;
        case _StockTableColumn.brand:
          return 150;
        case _StockTableColumn.category:
          return 130;
        case _StockTableColumn.imeiOrQty:
          return 140;
        case _StockTableColumn.statusOrStock:
          return 150;
        case _StockTableColumn.cost:
        case _StockTableColumn.price:
          return 110;
        case _StockTableColumn.location:
          return 140;
      }
    }
    switch (column) {
      case _StockTableColumn.type:
        return 84;
      case _StockTableColumn.condition:
        return 100;
      case _StockTableColumn.product:
        return 220;
      case _StockTableColumn.brand:
        return 120;
      case _StockTableColumn.category:
        return 120;
      case _StockTableColumn.imeiOrQty:
        return 120;
      case _StockTableColumn.statusOrStock:
        return 130;
      case _StockTableColumn.cost:
      case _StockTableColumn.price:
        return 96;
      case _StockTableColumn.location:
        return 120;
    }
  }
}
