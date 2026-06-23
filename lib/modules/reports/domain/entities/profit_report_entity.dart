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

  // Only damage/theft/loss write-offs are real financial losses.
  // Correction adjustments (both increase and decrease) are inventory data
  // fixes and do not represent actual financial gains or losses.
  double get netProfit =>
      grossProfit -
      totalExpenses -
      totalDamageLosses;

  /// Backward-compatible alias so existing call sites keep compiling.
  double get totalProfit => netProfit;

  double get marginPercent {
    if (totalRevenue <= 0) return 0;
    return (netProfit / totalRevenue) * 100;
  }
}
