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
    int? dealerStockCount,
  })  : _totalStockWorth = totalStockWorth,
        _dealerStockCount = dealerStockCount;

  final double todaySales;
  final double todayProfit;
  final int phonesSoldToday;
  final int accessoriesSoldToday;
  final int lowStockCount;
  final int availableStockCount;
  final double pendingBalances;
  final double? _totalStockWorth;
  final int? _dealerStockCount;

  double get totalStockWorth => _totalStockWorth ?? 0;
  int get dealerStockCount => _dealerStockCount ?? 0;
}
