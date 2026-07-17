class BrandStockEntity {
  const BrandStockEntity({
    required this.brandName,
    required this.brandLogo,
    required this.modelCount,
    required this.stockCount,
    double? stockWorth,
    int? lowStockCount,
  })  : _stockWorth = stockWorth,
        _lowStockCount = lowStockCount;

  final String brandName;
  final String brandLogo;
  final int modelCount;
  final int stockCount;
  final double? _stockWorth;
  final int? _lowStockCount;

  /// Total cost value of this brand's in-stock phones. 0 when not loaded.
  double get stockWorth => _stockWorth ?? 0;

  /// Accessory items of this brand at or below their minimum quantity.
  int get lowStockCount => _lowStockCount ?? 0;
}
