class ProfitRowEntity {
  const ProfitRowEntity({
    required this.day,
    required this.phonesSold,
    required this.accessoriesSold,
    required this.totalRevenue,
    required this.totalCost,
  });

  final String day;
  final int phonesSold;
  final int accessoriesSold;
  final double totalRevenue;
  final double totalCost;

  double get totalProfit => totalRevenue - totalCost;

  double get marginPercent {
    if (totalRevenue <= 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }
}
