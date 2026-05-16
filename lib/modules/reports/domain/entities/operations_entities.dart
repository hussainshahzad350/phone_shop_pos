class SalesHistoryRowEntity {
  const SalesHistoryRowEntity({
    required this.saleId,
    required this.invoiceNumber,
    required this.saleDate,
    required this.customerName,
    required this.customerId,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
    required this.printJobId,
  });

  final String saleId;
  final String invoiceNumber;
  final DateTime saleDate;
  final String customerName;
  final String? customerId;
  final double total;
  final double paidAmount;
  final String? paymentMethod;
  final String? printJobId;

  double get remainingBalance => (total - paidAmount).clamp(0, double.infinity);
  bool get isPaid => remainingBalance <= 0;
}

class SalesInvoiceItemEntity {
  const SalesInvoiceItemEntity({
    required this.saleItemId,
    required this.productModelId,
    required this.productName,
    required this.hasImei,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.serializedStockId,
    required this.imei,
    required this.returnedQty,
  });

  final String saleItemId;
  final String productModelId;
  final String productName;
  final bool hasImei;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? serializedStockId;
  final String? imei;
  final int returnedQty;

  int get returnableQty => (quantity - returnedQty).clamp(0, quantity);
}

class SalesInvoiceDetailEntity {
  const SalesInvoiceDetailEntity({
    required this.sale,
    required this.items,
    required this.notes,
  });

  final SalesHistoryRowEntity sale;
  final List<SalesInvoiceItemEntity> items;
  final String? notes;
}

class PurchaseHistoryRowEntity {
  const PurchaseHistoryRowEntity({
    required this.purchaseId,
    required this.purchaseDate,
    required this.supplierName,
    required this.invoiceNumber,
    required this.total,
    required this.paidAmount,
  });

  final String purchaseId;
  final DateTime purchaseDate;
  final String supplierName;
  final String? invoiceNumber;
  final double total;
  final double paidAmount;

  double get remainingBalance => (total - paidAmount).clamp(0, double.infinity);
}

class PurchaseHistoryItemEntity {
  const PurchaseHistoryItemEntity({
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    required this.imei,
  });

  final String productName;
  final int quantity;
  final double unitCost;
  final double lineTotal;
  final String? imei;
}

class PurchaseHistoryDetailEntity {
  const PurchaseHistoryDetailEntity({
    required this.purchase,
    required this.items,
    required this.notes,
  });

  final PurchaseHistoryRowEntity purchase;
  final List<PurchaseHistoryItemEntity> items;
  final String? notes;
}

class SupplierLedgerRowEntity {
  const SupplierLedgerRowEntity({
    required this.supplierName,
    required this.purchaseCount,
    required this.totalPurchases,
    required this.totalPaid,
  });

  final String supplierName;
  final int purchaseCount;
  final double totalPurchases;
  final double totalPaid;

  double get pendingAmount => (totalPurchases - totalPaid).clamp(0, double.infinity);
}

class StockAdjustmentHistoryRowEntity {
  const StockAdjustmentHistoryRowEntity({
    required this.id,
    required this.createdAt,
    required this.productName,
    required this.adjustmentType,
    required this.quantityDelta,
    required this.reason,
    required this.notes,
    required this.imei,
  });

  final String id;
  final DateTime createdAt;
  final String productName;
  final String adjustmentType;
  final int quantityDelta;
  final String reason;
  final String? notes;
  final String? imei;
}

class PaymentCollectionEntity {
  const PaymentCollectionEntity({
    required this.newPaidAmount,
    required this.remainingBalance,
  });

  final double newPaidAmount;
  final double remainingBalance;
}
