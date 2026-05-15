class CustomerBalanceReportRowEntity {
  const CustomerBalanceReportRowEntity({
    required this.customerName,
    required this.totalSales,
    required this.totalPaid,
    required this.pendingBalance,
  });

  final String customerName;
  final double totalSales;
  final double totalPaid;
  final double pendingBalance;
}
