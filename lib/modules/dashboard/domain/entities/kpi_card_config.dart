class KpiCardConfig {
  const KpiCardConfig({
    required this.id,
    required this.label,
    this.visible = true,
    required this.order,
  });

  final String id;
  final String label;
  final bool visible;
  final int order;

  KpiCardConfig copyWith({bool? visible, int? order}) => KpiCardConfig(
        id: id,
        label: label,
        visible: visible ?? this.visible,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'visible': visible,
        'order': order,
      };
}

const kpiCardDefaults = <KpiCardConfig>[
  KpiCardConfig(id: 'today_sales', label: 'Sales', order: 0),
  KpiCardConfig(id: 'today_profit', label: 'Profit', order: 1),
  KpiCardConfig(id: 'phones_sold_today', label: 'Phones Sold', order: 2),
  KpiCardConfig(id: 'accessories_sold_today', label: 'Accessories Sold', order: 3),
  KpiCardConfig(id: 'available_stock_count', label: 'Stock on Hand (units)', order: 4),
  KpiCardConfig(id: 'total_stock_worth', label: 'Total Stock Worth', order: 5),
  KpiCardConfig(id: 'pending_balances', label: 'Receivables (Udhaar)', order: 6),
  KpiCardConfig(id: 'low_stock_count', label: 'Low Stock Items', order: 7),
  KpiCardConfig(id: 'repairs_in_progress', label: 'Repairs in Progress', order: 8),
  KpiCardConfig(id: 'dealer_stock', label: 'Phones with Dealers', order: 9),
];
