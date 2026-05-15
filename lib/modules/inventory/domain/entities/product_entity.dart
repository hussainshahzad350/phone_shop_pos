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
    this.barcode,
    this.minStockAlert = 0,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? sku;
  final String? barcode;
  final int minStockAlert;
  final double purchasePrice;
  final double salePrice;
  final bool hasImei;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductEntity copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    String? sku,
    String? barcode,
    int? minStockAlert,
    double? purchasePrice,
    double? salePrice,
    bool? hasImei,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearSku = false,
    bool clearBarcode = false,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: clearBrand ? null : brand ?? this.brand,
      category: clearCategory ? null : category ?? this.category,
      sku: clearSku ? null : sku ?? this.sku,
      barcode: clearBarcode ? null : barcode ?? this.barcode,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      hasImei: hasImei ?? this.hasImei,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
