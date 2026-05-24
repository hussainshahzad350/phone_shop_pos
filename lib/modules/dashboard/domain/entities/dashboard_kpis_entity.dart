class DashboardKpisEntity {
  const DashboardKpisEntity({
    required this.todaySales,
    required this.todayProfit,
    required this.phonesSoldToday,
    required this.accessoriesSoldToday,
    required this.lowStockCount,
    required this.availableStockCount,
    required this.pendingBalances,
    double? totalStockWorth,
  }) : _totalStockWorth = totalStockWorth;

  final double todaySales;
  final double todayProfit;
  final int phonesSoldToday;
  final int accessoriesSoldToday;
  final int lowStockCount;
  final int availableStockCount;
  final double pendingBalances;
  final double? _totalStockWorth;

  double get totalStockWorth => _totalStockWorth ?? 0;
}
