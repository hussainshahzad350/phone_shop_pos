/// Time range selector for the dashboard "Key Metrics" section.
///
/// `today` covers the current local calendar day, `week` the rolling last
/// 7 local days (including today), and `month` the current local calendar
/// month to date.
enum DashboardRange {
  today,
  week,
  month;

  String get label {
    switch (this) {
      case DashboardRange.today:
        return 'Today';
      case DashboardRange.week:
        return 'Week';
      case DashboardRange.month:
        return 'Month';
    }
  }

  /// Human phrase used inside KPI labels, e.g. "This Week Sales".
  String get phrase {
    switch (this) {
      case DashboardRange.today:
        return 'Today';
      case DashboardRange.week:
        return 'This Week';
      case DashboardRange.month:
        return 'This Month';
    }
  }
}
