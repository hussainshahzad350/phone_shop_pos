import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/return_sale_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class SalesInvoiceDialog extends ConsumerWidget {
  const SalesInvoiceDialog({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(salesInvoiceDetailProvider(saleId));
    return AlertDialog(
      title: const Text('Invoice Details'),
      content: SizedBox(
        width: 980,
        height: 520,
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Invoice not found.');
            }
            final layout = reportTableLayoutFor(context);
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Invoice: ${detail.sale.invoiceNumber}'),
                    Text(
                      'Date: ${FormattingHelpers.dateYmd(detail.sale.saleDate)}',
                    ),
                    Text('Customer: ${detail.sale.customerName}'),
                    Text(
                      'Total: ${FormattingHelpers.currencyPkr(detail.sale.total)}',
                    ),
                    Text(
                      'Paid: ${FormattingHelpers.currencyPkr(detail.sale.paidAmount)}',
                    ),
                    Text(
                      'Remaining: ${FormattingHelpers.currencyPkr(detail.sale.remainingBalance)}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if ((detail.notes ?? '').isNotEmpty) ...<Widget>[
                  Text('Notes: ${detail.notes}'),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: AppDataTable(
                    columnSpacing: layout.columnSpacing,
                    dataRowMinHeight: layout.dataRowMinHeight,
                    dataRowMaxHeight: layout.dataRowMaxHeight,
                    showCheckboxColumn: false,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('IMEI')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Line Total')),
                      DataColumn(label: Text('Returned')),
                      DataColumn(label: Text('Return Action')),
                    ],
                    rows: detail.items.map((item) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(item.productName)),
                          DataCell(Text(item.imei ?? '-')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(
                            Text(FormattingHelpers.currencyPkr(item.unitPrice)),
                          ),
                          DataCell(
                            Text(FormattingHelpers.currencyPkr(item.lineTotal)),
                          ),
                          DataCell(Text(item.returnedQty.toString())),
                          DataCell(
                            item.returnableQty <= 0
                                ? const Text('Done')
                                : FilledButton.tonal(
                                    onPressed: () async {
                                      await showDialog<void>(
                                        context: context,
                                        builder: (context) => ReturnSaleDialog(
                                          saleId: saleId,
                                          item: item,
                                        ),
                                      );
                                      ref.invalidate(
                                        salesInvoiceDetailProvider(saleId),
                                      );
                                      ref.invalidate(dateRangeSalesReportProvider);
                                      ref.invalidate(dailySalesReportProvider);
                                      ref.invalidate(profitReportProvider);
                                      ref.invalidate(profitReportRowsProvider);
                                    },
                                    child: const Text('Return'),
                                  ),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Failed to load invoice details.'),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
