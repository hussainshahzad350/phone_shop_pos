/// Month-to-date top performers and today's activity counts shown in the
/// navigation sidebar ("This Month" indicators + nav badges).
class SidebarInsightsEntity {
  const SidebarInsightsEntity({
    this.topSellingBrand,
    this.topSellingModel,
    this.topCustomer,
    this.topAccessory,
    this.todaySalesCount = 0,
    this.todayPurchasesCount = 0,
  });

  static const SidebarInsightsEntity empty = SidebarInsightsEntity();

  /// Brand with the most units sold this month, null when no sales yet.
  final String? topSellingBrand;

  /// Phone model with the most units sold this month.
  final String? topSellingModel;

  /// Named customer with the highest sales total this month (walk-in
  /// customers are excluded — they share one anonymous identity).
  final String? topCustomer;

  /// Accessory with the most units sold this month.
  final String? topAccessory;

  /// Posted sales today — shown as the Sales nav badge.
  final int todaySalesCount;

  /// Posted purchases today — shown as the Purchases nav badge.
  final int todayPurchasesCount;

  bool get hasTopPerformers =>
      topSellingBrand != null ||
      topSellingModel != null ||
      topCustomer != null ||
      topAccessory != null;
}
