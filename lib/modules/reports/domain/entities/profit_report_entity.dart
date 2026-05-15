class ProfitReportEntity {
  const ProfitReportEntity({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
  });

  final double totalRevenue;
  final double totalCost;
  final double totalProfit;

  double get marginPercent {
    if (totalRevenue <= 0) {
      return 0;
    }
    return (totalProfit / totalRevenue) * 100;
  }
}
