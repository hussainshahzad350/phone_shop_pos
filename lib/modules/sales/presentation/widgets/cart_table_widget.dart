import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';

class CartTableWidget extends StatelessWidget {
  const CartTableWidget({
    super.key,
    required this.items,
    required this.onIncreaseQty,
    required this.onDecreaseQty,
    required this.onRemove,
    this.selectedIndex,
    this.onSelectRow,
  });

  final List<CartItemEntity> items;
  final ValueChanged<int> onIncreaseQty;
  final ValueChanged<int> onDecreaseQty;
  final ValueChanged<int> onRemove;
  final int? selectedIndex;
  final ValueChanged<int>? onSelectRow;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Cart is empty'));
    }

    return AppDataTable(
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
          selected: selectedIndex == index,
          onSelectChanged: (_) => onSelectRow?.call(index),
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
            DataCell(Text(item.unitPrice.toStringAsFixed(2))),
            DataCell(Text(item.lineTotal.toStringAsFixed(2))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onRemove(index),
              ),
            ),
          ],
        );
      }),
    );
  }
}
