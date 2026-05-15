class ProductEntity {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.purchasePrice,
    required this.salePrice,
    required this.hasImei,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.category,
    this.sku,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? sku;
  final double purchasePrice;
  final double salePrice;
  final bool hasImei;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
