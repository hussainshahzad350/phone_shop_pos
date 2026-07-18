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
    int? repairsInProgress,
  })  : _totalStockWorth = totalStockWorth,
        _dealerStockCount = dealerStockCount,
        _repairsInProgress = repairsInProgress;

  final double todaySales;
  final double todayProfit;
  final int phonesSoldToday;
  final int accessoriesSoldToday;
  final int lowStockCount;
  final int availableStockCount;
  final double pendingBalances;
  final double? _totalStockWorth;
  final int? _dealerStockCount;
  final int? _repairsInProgress;

  double get totalStockWorth => _totalStockWorth ?? 0;
  int get dealerStockCount => _dealerStockCount ?? 0;

  /// Open repair jobs (any status other than delivered/cancelled).
  int get repairsInProgress => _repairsInProgress ?? 0;
}
