class DailySalesReportRowEntity {
  const DailySalesReportRowEntity({
    required this.day,
    required this.invoiceCount,
    required this.totalSales,
    required this.totalProfit,
    required this.phonesSold,
    required this.accessoriesSold,
    required this.pendingBalances,
  });

  final String day;
  final int invoiceCount;
  final double totalSales;
  final double totalProfit;
  final int phonesSold;
  final int accessoriesSold;
  final double pendingBalances;
}
