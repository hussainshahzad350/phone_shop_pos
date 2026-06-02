import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_low_stock_entity.dart';

class DashboardLowStockPanel extends StatelessWidget {
  const DashboardLowStockPanel({
    super.key,
    required this.rows,
  });

  final List<DashboardLowStockEntity> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Low Stock Warnings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No low stock alerts.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                      ),
                      title: Text(row.productName),
                      subtitle: Text(
                        'Qty ${row.quantity} / Min ${row.minQuantity}'
                        '${row.location == null ? '' : ' • ${row.location}'}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
