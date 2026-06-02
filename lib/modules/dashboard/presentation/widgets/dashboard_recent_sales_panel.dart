import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_recent_sale_entity.dart';

class DashboardRecentSalesPanel extends StatelessWidget {
  const DashboardRecentSalesPanel({
    super.key,
    required this.rows,
    required this.onOpenInvoice,
  });

  final List<DashboardRecentSaleEntity> rows;
  final Future<void> Function(String saleId) onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Recent Sales', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No sales found.'))
              : Builder(
                  builder: (context) {
                    final layout = DashboardRecentSalesLayout.fromWidth(
                      MediaQuery.sizeOf(context).width,
                    );
                    final visibleColumns = _visibleColumns;
                    return Column(
                      children: <Widget>[
                        Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: visibleColumns
                                .map(
                                  (column) => _headerCell(
                                    _columnLabel(column),
                                    width: layout.valueWidth(column),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return SizedBox(
                                height: layout.dataRowMinHeight,
                                child: Row(
                                  children: visibleColumns
                                      .map(
                                        (column) => _buildRowCell(
                                          row: row,
                                          column: column,
                                          layout: layout,
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  static const List<DashboardRecentSalesColumn> _visibleColumns =
      <DashboardRecentSalesColumn>[
    DashboardRecentSalesColumn.invoice,
    DashboardRecentSalesColumn.date,
    DashboardRecentSalesColumn.total,
    DashboardRecentSalesColumn.customer,
    DashboardRecentSalesColumn.view,
  ];

  String _columnLabel(DashboardRecentSalesColumn column) {
    switch (column) {
      case DashboardRecentSalesColumn.invoice:
        return 'Invoice';
      case DashboardRecentSalesColumn.date:
        return 'Date';
      case DashboardRecentSalesColumn.customer:
        return 'Customer';
      case DashboardRecentSalesColumn.total:
        return 'Total';
      case DashboardRecentSalesColumn.view:
        return 'Open';
    }
  }

  Widget _buildRowCell({
    required DashboardRecentSaleEntity row,
    required DashboardRecentSalesColumn column,
    required DashboardRecentSalesLayout layout,
  }) {
    switch (column) {
      case DashboardRecentSalesColumn.invoice:
        return _valueCell(
          row.invoiceNumber,
          width: layout.valueWidth(column),
        );
      case DashboardRecentSalesColumn.date:
        return _valueCell(
          FormattingHelpers.dateYmdHm(row.saleDate),
          width: layout.valueWidth(column),
        );
      case DashboardRecentSalesColumn.customer:
        return _valueCell(
          row.customerName,
          width: layout.valueWidth(column),
        );
      case DashboardRecentSalesColumn.total:
        return _valueCell(
          FormattingHelpers.currencyPkr(row.total),
          width: layout.valueWidth(column),
        );
      case DashboardRecentSalesColumn.view:
        return SizedBox(
          width: layout.valueWidth(column),
          child: Align(
            alignment: Alignment.center,
            child: IconButton(
              tooltip: 'View invoice',
              onPressed: (row.saleId == null || row.saleId!.isEmpty)
                  ? null
                  : () => onOpenInvoice(row.saleId!),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
          ),
        );
    }
  }

  Widget _headerCell(String text, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _valueCell(
    String text, {
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

enum DashboardRecentSalesColumn {
  invoice,
  date,
  customer,
  total,
  view,
}

class DashboardRecentSalesLayout {
  const DashboardRecentSalesLayout({
    required this.dataRowMinHeight,
    required this.isWideDesktop,
  });

  final double dataRowMinHeight;
  final bool isWideDesktop;

  factory DashboardRecentSalesLayout.fromWidth(double width) {
    if (width >= 1400) {
      return const DashboardRecentSalesLayout(
        dataRowMinHeight: 50,
        isWideDesktop: true,
      );
    }
    if (width >= 1080) {
      return const DashboardRecentSalesLayout(
        dataRowMinHeight: 44,
        isWideDesktop: false,
      );
    }
    return const DashboardRecentSalesLayout(
      dataRowMinHeight: 40,
      isWideDesktop: false,
    );
  }

  double valueWidth(DashboardRecentSalesColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case DashboardRecentSalesColumn.invoice:
          return 145;
        case DashboardRecentSalesColumn.date:
          return 170;
        case DashboardRecentSalesColumn.customer:
          return 250;
        case DashboardRecentSalesColumn.total:
          return 120;
        case DashboardRecentSalesColumn.view:
          return 52;
      }
    }

    switch (column) {
      case DashboardRecentSalesColumn.invoice:
        return 140;
      case DashboardRecentSalesColumn.date:
        return 165;
      case DashboardRecentSalesColumn.customer:
        return 230;
      case DashboardRecentSalesColumn.total:
        return 126;
      case DashboardRecentSalesColumn.view:
        return 52;
    }
  }
}
