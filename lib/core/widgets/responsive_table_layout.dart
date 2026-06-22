/// Shared responsive metrics for the app's desktop data tables.
///
/// Every screen's table previously re-declared an identical `_XTableLayout`
/// class with the same width breakpoints (1600 / 1220) and the same row
/// height / column-spacing values. That scaffold now lives here once; each
/// screen keeps only its own per-column width `switch` (which is inherently
/// screen-specific) and delegates the responsive metrics to
/// [ResponsiveTableLayout.fromWidth].
///
/// Column spacing is parameterized because a few dense tables (e.g. repair
/// jobs) need tighter spacing than the default; row heights and the
/// wide/medium/compact tier flags are uniform across all tables.
class ResponsiveTableLayout {
  const ResponsiveTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.showMediumColumns,
    required this.showCompactColumns,
    required this.isWideDesktop,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showMediumColumns;
  final bool showCompactColumns;
  final bool isWideDesktop;

  /// Resolves the responsive tier for [width].
  ///
  /// `wideSpacing` / `mediumSpacing` / `compactSpacing` default to the standard
  /// table spacing; pass tighter values for dense tables.
  factory ResponsiveTableLayout.fromWidth(
    double width, {
    double wideSpacing = 28,
    double mediumSpacing = 20,
    double compactSpacing = 14,
  }) {
    if (width >= 1600) {
      return ResponsiveTableLayout(
        columnSpacing: wideSpacing,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1220) {
      return ResponsiveTableLayout(
        columnSpacing: mediumSpacing,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return ResponsiveTableLayout(
      columnSpacing: compactSpacing,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }
}
