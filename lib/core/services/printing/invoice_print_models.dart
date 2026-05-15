import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

enum InvoicePaperSize {
  thermal58,
  thermal80,
  a4,
}

extension InvoicePaperSizeX on InvoicePaperSize {
  String get label => switch (this) {
    InvoicePaperSize.thermal58 => 'Thermal 58mm',
    InvoicePaperSize.thermal80 => 'Thermal 80mm',
    InvoicePaperSize.a4 => 'A4 Invoice',
  };

  int get charactersPerLine => switch (this) {
    InvoicePaperSize.thermal58 => 28,
    InvoicePaperSize.thermal80 => 40,
    InvoicePaperSize.a4 => 90,
  };
}

class InvoicePrintDocument {
  const InvoicePrintDocument({
    required this.saleId,
    required this.invoiceNumber,
    required this.saleDate,
    required this.items,
    required this.totals,
    required this.paymentMethod,
    this.customerLabel,
    this.notes,
    this.cashierName,
    this.storeName = 'Phone Shop POS',
  });

  final String saleId;
  final String invoiceNumber;
  final DateTime saleDate;
  final List<CartItemEntity> items;
  final SaleTotalsEntity totals;
  final String paymentMethod;
  final String? customerLabel;
  final String? notes;
  final String? cashierName;
  final String storeName;
}

class InvoicePrintJob {
  const InvoicePrintJob({
    required this.id,
    required this.invoiceNumber,
    required this.document,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String invoiceNumber;
  final InvoicePrintDocument document;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  InvoicePrintJob copyWith({
    int? attempts,
    String? lastError,
    bool clearLastError = false,
  }) {
    return InvoicePrintJob(
      id: id,
      invoiceNumber: invoiceNumber,
      document: document,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}
