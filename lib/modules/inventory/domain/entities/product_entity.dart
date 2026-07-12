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
    this.barcode,
    this.minStockAlert = 0,
    this.supplierId,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? barcode;
  final int minStockAlert;
  final double purchasePrice;
  final double salePrice;
  final bool hasImei;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? supplierId;

  ProductEntity copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    String? barcode,
    int? minStockAlert,
    double? purchasePrice,
    double? salePrice,
    bool? hasImei,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierId,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearBarcode = false,
    bool clearSupplierId = false,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: clearBrand ? null : brand ?? this.brand,
      category: clearCategory ? null : category ?? this.category,
      barcode: clearBarcode ? null : barcode ?? this.barcode,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      hasImei: hasImei ?? this.hasImei,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierId: clearSupplierId ? null : supplierId ?? this.supplierId,
    );
  }
}
