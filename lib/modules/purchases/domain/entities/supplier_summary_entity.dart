/// Aggregate purchase/stock snapshot for one supplier, computed at query
/// time from `purchases` and `serialized_stock` — not a persisted/cached
/// value, so it's always consistent with the underlying records.
class SupplierSummaryEntity {
  const SupplierSummaryEntity({
    required this.supplierId,
    required this.name,
    required this.totalPurchases,
    required this.currentStock,
    required this.totalPurchaseValue,
    this.phone,
    this.email,
    this.lastPurchaseDate,
  });

  final String supplierId;
  final String name;
  final String? phone;
  final String? email;
  final int totalPurchases;
  final int currentStock;
  final double totalPurchaseValue;
  final DateTime? lastPurchaseDate;
}

/// One row of a supplier's purchase/inventory history.
class SupplierPurchaseHistoryRowEntity {
  const SupplierPurchaseHistoryRowEntity({
    required this.productName,
    required this.quantity,
    this.brand,
    this.imei,
    this.purchaseDate,
    this.purchasePrice,
    this.currentStatus,
    this.invoiceNumber,
  });

  final String productName;
  final String? brand;
  final String? imei;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? currentStatus;
  final String? invoiceNumber;
  final int quantity;
}
