class BrandStockEntity {
  const BrandStockEntity({
    required this.brandName,
    required this.brandLogo,
    required this.modelCount,
    required this.stockCount,
  });

  final String brandName;
  final String brandLogo;
  final int modelCount;
  final int stockCount;
}
