import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';

class CartTableWidget extends StatelessWidget {
  const CartTableWidget({
    super.key,
    required this.items,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onRemove,
  });

  final List<CartItemEntity> items;
  final ValueChanged<int> onIncreaseQty;
  final ValueChanged<int> onDecreaseQty;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Cart is empty'));
    }

    return SingleChildScrollView(
      child: DataTable(
        dataRowMinHeight: 56,
        dataRowMaxHeight: 56,
        columns: const <DataColumn>[
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('IMEI')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Actions')),
        ],
        rows: List<DataRow>.generate(items.length, (index) {
          final item = items[index];

          return DataRow(
            cells: <DataCell>[
              DataCell(Text(item.productName)),
              DataCell(Text(item.imei ?? '-')),
              DataCell(
                item.hasImei
                    ? const Text('1')
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => onDecreaseQty(index),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => onIncreaseQty(index),
                          ),
                        ],
                      ),
              ),
              DataCell(Text(item.unitPrice.toStringAsFixed(0))),
              DataCell(Text(item.lineTotal.toStringAsFixed(0))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemove(index),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
