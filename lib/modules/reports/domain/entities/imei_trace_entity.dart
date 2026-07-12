/// Full purchase + sale history for a single IMEI.
class ImeiTraceEntity {
  const ImeiTraceEntity({
    required this.serializedStockId,
    required this.imei1,
    required this.productName,
    required this.brandName,
    required this.stockStatus,
    required this.costPrice,
    this.imei2,
    this.purchaseDate,
    this.supplierName,
    this.saleDate,
    this.salePrice,
    this.customerName,
    this.customerPhone,
    this.invoiceNumber,
    this.remainingWarranty,
  });

  final String serializedStockId;
  final String imei1;
  final String? imei2;
  final String productName;
  final String brandName;

  /// Raw value from serialized_stock.stock_status (e.g. 'in_stock', 'sold').
  final String stockStatus;

  // ── Purchase info ──────────────────────────────────────────────────────────
  final DateTime? purchaseDate;
  final double costPrice;
  final String? supplierName;

  // ── Sale info (null when not yet sold) ────────────────────────────────────
  final DateTime? saleDate;
  final double? salePrice;
  final String? customerName;
  final String? customerPhone;
  final String? invoiceNumber;
  final String? remainingWarranty;

  bool get isSold => saleDate != null && invoiceNumber != null;

  /// Realized profit for a sold unit, or null when not yet sold.
  double? get profit => salePrice == null ? null : salePrice! - costPrice;
}
