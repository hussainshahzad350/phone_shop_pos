import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

// The stock query is capped at ~200 rows, so keep the table on the continuous
// (sticky-header, single-scroll) path instead of PaginatedDataTable — that path
// scrolls with the mouse wheel and matches the Reports tables.
const int _kStockPaginateThreshold = 100000;

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
        // Flex the Product column so the table fills the card width instead of
        // floating as a narrow block (matches the Reports tables).
        final productWidth =
            _productWidth(constraints.maxWidth, visibleColumns, layout);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          showCheckboxColumn: false,
          paginateThreshold: _kStockPaginateThreshold,
          columns: visibleColumns
              .map((column) =>
                  _buildDataColumn(context, column, layout, productWidth))
              .toList(growable: false),
          rows: rows
              .asMap()
              .entries
              .map((e) => _buildResponsiveRow(
                    context,
                    e.value,
                    visibleColumns,
                    layout,
                    productWidth,
                    e.key,
                  ))
              .toList(growable: false),
        );
      },
    );
  }

  /// Width for a column, substituting the flexed Product width.
  double _colWidth(
    _StockTableColumn column,
    _StockTableLayout layout,
    double productWidth,
  ) {
    return column == _StockTableColumn.product
        ? productWidth
        : layout.valueWidth(column);
  }

  /// Computes the Product column width so all columns together fill the
  /// available width, with the other (fixed) columns keeping their widths.
  double _productWidth(
    double maxWidth,
    List<_StockTableColumn> visibleColumns,
    _StockTableLayout layout,
  ) {
    var fixedSum = 0.0;
    for (final column in visibleColumns) {
      if (column != _StockTableColumn.product) {
        fixedSum += layout.valueWidth(column);
      }
    }
    final spacing = layout.columnSpacing * (visibleColumns.length - 1);
    const buffer = 28.0;
    final remaining = maxWidth - fixedSum - spacing - buffer;
    final minWidth = layout.valueWidth(_StockTableColumn.product);
    return remaining > minWidth ? remaining : minWidth;
  }

  List<_StockTableColumn> _visibleColumns(_StockTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_StockTableColumn>[
        _StockTableColumn.serial,
        _StockTableColumn.type,
        _StockTableColumn.product,
        _StockTableColumn.imeiOrQty,
        _StockTableColumn.statusOrStock,
        _StockTableColumn.price,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_StockTableColumn>[
        _StockTableColumn.serial,
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
      _StockTableColumn.serial,
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
    BuildContext context,
    _StockTableColumn column,
    _StockTableLayout layout,
    double productWidth,
  ) {
    final isNumeric =
        column == _StockTableColumn.cost || column == _StockTableColumn.price;
    return DataColumn(
      numeric: isNumeric,
      label: reportStyledTableHeaderCell(
        context,
        _columnLabel(column),
        width: _colWidth(column, layout, productWidth),
        textAlign: isNumeric ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  DataRow _buildResponsiveRow(
    BuildContext context,
    StockRowEntity row,
    List<_StockTableColumn> columns,
    _StockTableLayout layout,
    double productWidth,
    int rowIndex,
  ) {
    return DataRow(
      cells: columns
          .map((column) =>
              _buildDataCell(context, row, column, layout, productWidth, rowIndex))
          .toList(growable: false),
    );
  }

  DataCell _buildDataCell(
    BuildContext context,
    StockRowEntity row,
    _StockTableColumn column,
    _StockTableLayout layout,
    double productWidth,
    int rowIndex,
  ) {
    final isSerialized = row.type == StockRowType.serialized;
    switch (column) {
      case _StockTableColumn.serial:
        return DataCell(
          _textCell('${rowIndex + 1}', width: _colWidth(column, layout, productWidth)),
        );
      case _StockTableColumn.type:
        return DataCell(
          _textCell(
            isSerialized ? 'Phone' : 'Accessory',
            width: _colWidth(column, layout, productWidth),
          ),
        );
      case _StockTableColumn.condition:
        if (!isSerialized) {
          return DataCell(_textCell('—', width: _colWidth(column, layout, productWidth)));
        }
        final isUsed = row.condition == SerializedStockCondition.used;
        return DataCell(
          reportSemanticPill(
            context,
            isUsed ? 'Used' : 'New',
            isUsed ? ReportPillIntent.warning : ReportPillIntent.info,
            width: _colWidth(column, layout, productWidth),
          ),
        );
      case _StockTableColumn.product:
        return DataCell(
          _textCell(
            row.productName,
            width: _colWidth(column, layout, productWidth),
            maxLines: 1,
          ),
        );
      case _StockTableColumn.brand:
        return DataCell(
          _textCell(row.brand ?? '—', width: _colWidth(column, layout, productWidth)),
        );
      case _StockTableColumn.category:
        return DataCell(
          _textCell(row.category ?? '—', width: _colWidth(column, layout, productWidth)),
        );
      case _StockTableColumn.imeiOrQty:
        if (isSerialized) {
          return DataCell(
            _textCell(_formatImei(row.imei1), width: _colWidth(column, layout, productWidth)),
          );
        }
        return DataCell(
          _textCell(
            row.quantity?.toString() ?? '—',
            width: _colWidth(column, layout, productWidth),
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
          final badge = _statusBadge(row.serializedStatus);
          return DataCell(
            badge == null
                ? _textCell('—', width: _colWidth(column, layout, productWidth))
                : reportSemanticPill(
                    context,
                    badge.label,
                    badge.intent,
                    width: _colWidth(column, layout, productWidth),
                  ),
          );
        }
        return DataCell(
          reportSemanticPill(
            context,
            row.isLowStock ? 'Low Stock' : 'In Stock',
            row.isLowStock ? ReportPillIntent.danger : ReportPillIntent.success,
            width: _colWidth(column, layout, productWidth),
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
            width: _colWidth(column, layout, productWidth),
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
            width: _colWidth(column, layout, productWidth),
            textAlign: TextAlign.right,
          ),
        );
      case _StockTableColumn.location:
        return DataCell(
          _textCell(row.location ?? '—', width: _colWidth(column, layout, productWidth)),
        );
    }
  }

  String _columnLabel(_StockTableColumn column) {
    switch (column) {
      case _StockTableColumn.serial:
        return '#';
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

  ({String label, ReportPillIntent intent})? _statusBadge(
    SerializedStockStatus? status,
  ) {
    switch (status) {
      case SerializedStockStatus.inStock:
        return (label: 'In Stock', intent: ReportPillIntent.success);
      case SerializedStockStatus.sold:
        return (label: 'Sold', intent: ReportPillIntent.neutral);
      case SerializedStockStatus.reserved:
        return (label: 'Reserved', intent: ReportPillIntent.warning);
      case SerializedStockStatus.returned:
        return (label: 'Returned', intent: ReportPillIntent.info);
      case SerializedStockStatus.damaged:
        return (label: 'Damaged', intent: ReportPillIntent.danger);
      case SerializedStockStatus.withDealer:
        return (label: 'With Dealer', intent: ReportPillIntent.warning);
      case null:
        return null;
    }
  }
}

enum _StockTableColumn {
  serial,
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

  double valueWidth(_StockTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _StockTableColumn.serial:
          return 40;
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
        case _StockTableColumn.serial:
          return 40;
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
      case _StockTableColumn.serial:
        return 40;
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
