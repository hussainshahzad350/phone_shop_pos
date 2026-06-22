import 'package:phone_shop_pos/modules/sales/domain/entities/sale_status.dart';

class SaleHeaderEntity {
  const SaleHeaderEntity({
    required this.id,
    required this.invoiceNumber,
    required this.total,
    required this.paidAmount,
    required this.status,
    this.customerId,
    this.paymentMethod,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.correctionOf,
  });

  final String id;
  final String invoiceNumber;
  final String? customerId;
  final double total;
  final double paidAmount;
  final String? paymentMethod;
  final SaleStatus status;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? correctionOf;
}
