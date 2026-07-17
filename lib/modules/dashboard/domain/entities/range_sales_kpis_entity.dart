/// Sales-derived KPIs for an arbitrary date range (today / week / month).
///
/// Mirrors the range-independent fields of `DashboardKpisEntity` that change
/// with the selected range on the dashboard: sales, profit and units sold.
class RangeSalesKpisEntity {
  const RangeSalesKpisEntity({
    required this.sales,
    required this.profit,
    required this.phonesSold,
    required this.accessoriesSold,
  });

  static const RangeSalesKpisEntity empty = RangeSalesKpisEntity(
    sales: 0,
    profit: 0,
    phonesSold: 0,
    accessoriesSold: 0,
  );

  final double sales;
  final double profit;
  final int phonesSold;
  final int accessoriesSold;
}
