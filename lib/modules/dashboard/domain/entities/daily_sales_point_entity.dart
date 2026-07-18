/// One bar of the "Sales — last 7 days" chart: net sales total for a single
/// local calendar day.
class DailySalesPointEntity {
  const DailySalesPointEntity({
    required this.day,
    required this.total,
  });

  /// Local midnight of the day this point represents.
  final DateTime day;

  /// Net sales for the day (posted sales minus returns recorded that day).
  final double total;
}
