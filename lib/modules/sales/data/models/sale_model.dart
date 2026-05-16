import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/shared/models/base_db_model.dart';

class SaleModel extends BaseDbModel {
  const SaleModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.invoiceNumber,
    required this.saleDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    this.customerId,
    this.userId,
    this.paymentMethod,
    this.notes,
  });

  final String invoiceNumber;
  final String? customerId;
  final String? userId;
  final DateTime saleDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String? paymentMethod;
  final String? notes;

  factory SaleModel.fromMap(Map<String, Object?> map) {
    return SaleModel(
      id: map['id'] as String,
      createdAt: DateTimeHelpers.fromSql(map['created_at'] as String),
      updatedAt: DateTimeHelpers.fromSql(map['updated_at'] as String),
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as String?,
      userId: map['user_id'] as String?,
      saleDate: DateTimeHelpers.fromSql(map['sale_date'] as String),
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      tax: (map['tax'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.normalizeNullable(
        map['payment_method'] as String?,
      ),
      notes: map['notes'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      ...toBaseMap(),
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'user_id': userId,
      'sale_date': DateTimeHelpers.toSql(saleDate),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid_amount': paidAmount,
      'payment_method': PaymentMethod.normalizeNullable(paymentMethod),
      'notes': notes,
    };
  }
}
