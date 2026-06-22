class ProfitReportEntity {
  const ProfitReportEntity({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalExpenses,
    required this.totalDamageLosses,
    required this.totalAdjLosses,
    required this.totalAdjGains,
  });

  final double totalRevenue;
  final double totalCost;
  final double totalExpenses;
  final double totalDamageLosses;
  final double totalAdjLosses;
  final double totalAdjGains;

  double get grossProfit => totalRevenue - totalCost;

  double get netProfit =>
      grossProfit -
      totalExpenses -
      totalDamageLosses -
      totalAdjLosses +
      totalAdjGains;

  /// Backward-compatible alias so existing call sites keep compiling.
  double get totalProfit => netProfit;

  double get marginPercent {
    if (totalRevenue <= 0) return 0;
    return (netProfit / totalRevenue) * 100;
  }
}
