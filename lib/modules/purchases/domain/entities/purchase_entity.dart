class PurchaseEntity {
  const PurchaseEntity({
    required this.id,
    required this.purchaseDate,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.invoiceNumber,
    this.notes,
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
  final DateTime createdAt;
  final DateTime updatedAt;
}
