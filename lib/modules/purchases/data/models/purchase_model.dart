import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class PurchaseModel extends BaseDbModel {
  const PurchaseModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.purchaseDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    this.supplierId,
    this.invoiceNumber,
    this.notes,
  });

  final String? supplierId;
  final String? invoiceNumber;
  final DateTime purchaseDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String? notes;

  factory PurchaseModel.fromMap(Map<String, Object?> map) {
    return PurchaseModel(
      id: map['id'] as String,
      supplierId: map['supplier_id'] as String?,
      invoiceNumber: map['invoice_number'] as String?,
      purchaseDate: DateTimeHelpers.fromSql(map['purchase_date'] as String),
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      tax: (map['tax'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
    );
  }

  factory PurchaseModel.fromEntity(PurchaseEntity entity) {
    return PurchaseModel(
      id: entity.id,
      supplierId: entity.supplierId,
      invoiceNumber: entity.invoiceNumber,
      purchaseDate: entity.purchaseDate,
      subtotal: entity.subtotal,
      discount: entity.discount,
      tax: entity.tax,
      total: entity.total,
      paidAmount: entity.paidAmount,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'supplier_id': supplierId,
      'invoice_number': invoiceNumber,
      'purchase_date': DateTimeHelpers.toSql(purchaseDate),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid_amount': paidAmount,
      'notes': notes,
    };
  }

  PurchaseEntity toEntity() {
    return PurchaseEntity(
      id: id,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      purchaseDate: purchaseDate,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      paidAmount: paidAmount,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
