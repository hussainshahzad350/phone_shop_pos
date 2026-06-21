class FeatureFlags {
  const FeatureFlags({
    required this.imeiStock,
    required this.qtyStock,
    required this.repairModule,
    required this.accessoriesModule,
    required this.dealerIssueModule,
    required this.reports,
    required this.navigationStyle,
  });

  const FeatureFlags.currentBehaviorDefaults()
      : imeiStock = true,
        qtyStock = true,
        repairModule = false,
        accessoriesModule = false,
        dealerIssueModule = false,
        reports = true,
        navigationStyle = false;

  final bool imeiStock;
  final bool qtyStock;
  final bool repairModule;
  final bool accessoriesModule;
  final bool dealerIssueModule;
  final bool reports;
  final bool navigationStyle;

  FeatureFlags copyWith({
    bool? imeiStock,
    bool? qtyStock,
    bool? repairModule,
    bool? accessoriesModule,
    bool? dealerIssueModule,
    bool? reports,
    bool? navigationStyle,
  }) {
    return FeatureFlags(
      imeiStock: imeiStock ?? this.imeiStock,
      qtyStock: qtyStock ?? this.qtyStock,
      repairModule: repairModule ?? this.repairModule,
      accessoriesModule: accessoriesModule ?? this.accessoriesModule,
      dealerIssueModule: dealerIssueModule ?? this.dealerIssueModule,
      reports: reports ?? this.reports,
      navigationStyle: navigationStyle ?? this.navigationStyle,
    );
  }

  factory FeatureFlags.fromMap(
    Map<String, Object?> values, {
    FeatureFlags defaults = const FeatureFlags.currentBehaviorDefaults(),
  }) {
    return defaults.copyWith(
      imeiStock: _boolOrNull(values['imeiStock']),
      qtyStock: _boolOrNull(values['qtyStock']),
      repairModule: _boolOrNull(values['repairModule']),
      accessoriesModule: _boolOrNull(values['accessoriesModule']),
      dealerIssueModule: _boolOrNull(values['dealerIssueModule']),
      reports: _boolOrNull(values['reports']),
      navigationStyle: _boolOrNull(values['navigationStyle']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'imeiStock': imeiStock,
      'qtyStock': qtyStock,
      'repairModule': repairModule,
      'accessoriesModule': accessoriesModule,
      'dealerIssueModule': dealerIssueModule,
      'reports': reports,
      'navigationStyle': navigationStyle,
    };
  }

  static bool? _boolOrNull(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is FeatureFlags &&
        other.imeiStock == imeiStock &&
        other.qtyStock == qtyStock &&
        other.repairModule == repairModule &&
        other.accessoriesModule == accessoriesModule &&
        other.dealerIssueModule == dealerIssueModule &&
        other.reports == reports &&
        other.navigationStyle == navigationStyle;
  }

  @override
  int get hashCode => Object.hash(
        imeiStock,
        qtyStock,
        repairModule,
        accessoriesModule,
        dealerIssueModule,
        reports,
        navigationStyle,
      );
}
