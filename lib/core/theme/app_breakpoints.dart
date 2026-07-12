/// Shared width breakpoints for desktop-responsive layouts.
///
/// This does NOT replace [ResponsiveTableLayout] (table column/row sizing has
/// its own 1220/1600 tiering) — it centralizes the *other* ad hoc width
/// thresholds that were previously copy-pasted verbatim across multiple
/// widgets, so a future tuning only has to change one place and every
/// consumer stays in sync.
abstract final class AppBreakpoints {
  // ── KPI card grid (Dashboard + Repairing) ──────────────────────────────
  // Column-count tiering shared by dashboard_kpi_grid.dart, its loading
  // skeleton in dashboard_screen.dart, and repairing_kpi_row.dart.
  static const double kpiGridWide = 1500;
  static const double kpiGridMedium = 1100;
  static const double kpiGridCompact = 760;

  /// Card count per row for the KPI grid at the given available [width].
  static int kpiGridColumns(double width) {
    if (width >= kpiGridWide) return 5;
    if (width >= kpiGridMedium) return 4;
    if (width >= kpiGridCompact) return 3;
    return 2;
  }

  // ── Quick product-tile bar (Sales + Purchases) ─────────────────────────
  static const double productTileWide = 1400;
  static const double productTileWideExtent = 168.0;
  static const double productTileCompactExtent = 180.0;

  /// Grid tile main-axis extent for the horizontal quick-product bar.
  static double productTileExtent(double width) =>
      width >= productTileWide ? productTileWideExtent : productTileCompactExtent;

  // ── Billing/purchase screen right-side summary panel ───────────────────
  static const double rightPanelWide = 1500;
  static const double rightPanelMedium = 1200;
  static const double rightPanelWideWidth = 360.0;
  static const double rightPanelMediumWidth = 320.0;
  static const double rightPanelCompactWidth = 300.0;

  /// Right-panel (totals/cart summary) width for Sales/Purchases screens.
  static double rightPanelWidth(double width) {
    if (width >= rightPanelWide) return rightPanelWideWidth;
    if (width >= rightPanelMedium) return rightPanelMediumWidth;
    return rightPanelCompactWidth;
  }
}
