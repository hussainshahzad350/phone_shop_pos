import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
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
              ? const AppEmptyState(
                  message: 'No low stock alerts.',
                  icon: Icons.check_circle_outline,
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).semantic.warning,
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
