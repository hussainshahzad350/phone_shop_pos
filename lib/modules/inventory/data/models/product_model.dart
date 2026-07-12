import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class ProductModel extends BaseDbModel {
  const ProductModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.purchasePrice,
    required this.salePrice,
    required this.hasImei,
    required this.isActive,
    this.brand,
    this.category,
    this.barcode,
    this.minStockAlert = 0,
    this.supplierId,
  });

  final String name;
  final String? brand;
  final String? category;
  final String? barcode;
  final int minStockAlert;
  final double purchasePrice;
  final double salePrice;
  final bool hasImei;
  final bool isActive;
  final String? supplierId;

  factory ProductModel.fromMap(Map<String, Object?> map) {
    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      barcode: map['barcode'] as String?,
      minStockAlert: (map['min_stock_alert'] as num?)?.toInt() ?? 0,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      hasImei: (map['has_imei'] as num) == 1,
      isActive: (map['is_active'] as num) == 1,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
      supplierId: map['supplier_id'] as String?,
    );
  }

  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id,
      name: entity.name,
      brand: entity.brand,
      category: entity.category,
      barcode: entity.barcode,
      minStockAlert: entity.minStockAlert,
      purchasePrice: entity.purchasePrice,
      salePrice: entity.salePrice,
      hasImei: entity.hasImei,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      supplierId: entity.supplierId,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'name': name,
      'brand': brand,
      'category': category,
      'barcode': barcode,
      'min_stock_alert': minStockAlert,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'has_imei': hasImei ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'supplier_id': supplierId,
    };
  }

  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      name: name,
      brand: brand,
      category: category,
      barcode: barcode,
      minStockAlert: minStockAlert,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      hasImei: hasImei,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      supplierId: supplierId,
    );
  }
}
