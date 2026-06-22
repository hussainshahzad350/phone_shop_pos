import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_status.dart';

class PurchaseEntity {
  const PurchaseEntity({
    required this.id,
    required this.purchaseDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.invoiceNumber,
    this.notes,
    this.paymentMethod,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.correctionOf,
  });

  final String id;
  final String? supplierId;
  final String? invoiceNumber;
  final DateTime purchaseDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String? notes;
  final String? paymentMethod;
  final PurchaseStatus status;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? correctionOf;
  final DateTime createdAt;
  final DateTime updatedAt;
}
