import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/return_purchase_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';

class PurchaseDetailDialog extends ConsumerWidget {
  const PurchaseDetailDialog({super.key, required this.purchaseId});

  final String purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseHistoryDetailProvider(purchaseId));
    return AlertDialog(
      title: const Text('Purchase Details'),
      content: SizedBox(
        width: 920,
        height: 500,
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Purchase not found.');
            }
            final layout = reportTableLayoutFor(context);
            final isVoided = detail.purchase.status == 'void';
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isVoided) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'This purchase has been cancelled. Stock was reversed and '
                      'returns are disabled.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Supplier: ${detail.purchase.supplierName}'),
                    if (detail.purchase.sellerName?.trim().isNotEmpty == true)
                      Text('Seller: ${detail.purchase.sellerName}'),
                    Text(
                      'Date: ${FormattingHelpers.dateYmd(detail.purchase.purchaseDate)}',
                    ),
                    Text('Invoice: ${detail.purchase.invoiceNumber ?? '-'}'),
                    Text(
                      'Total: ${FormattingHelpers.currencyPkr(detail.purchase.total)}',
                    ),
                    Text(
                      'Paid: ${FormattingHelpers.currencyPkr(detail.purchase.paidAmount)}',
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
                      DataColumn(label: Text('Unit Cost')),
                      DataColumn(label: Text('Line Total')),
                      DataColumn(label: Text('Returns')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: detail.items.map((item) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(item.productName)),
                          DataCell(Text(item.imei ?? '-')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(
                            Text(FormattingHelpers.currencyPkr(item.unitCost)),
                          ),
                          DataCell(
                            Text(FormattingHelpers.currencyPkr(item.lineTotal)),
                          ),
                          DataCell(Text(item.returnedQty.toString())),
                          DataCell(
                            (!isVoided && item.returnableQty > 0)
                                ? TextButton(
                                    onPressed: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (context) =>
                                            ReturnPurchaseDialog(
                                          purchaseId: detail.purchase.purchaseId,
                                          item: item,
                                        ),
                                      );
                                    },
                                    child: const Text('Return'),
                                  )
                                : const SizedBox.shrink(),
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
          error: (_, __) => const Text('Failed to load purchase details.'),
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
