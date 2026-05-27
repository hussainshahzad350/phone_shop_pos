class CustomerSettlementRequestPayload {
  const CustomerSettlementRequestPayload({
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.note,
    this.createdBy,
    this.idempotencyKey,
  });

  final String customerId;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String? createdBy;
  final String? idempotencyKey;
}

class SupplierSettlementRequestPayload {
  const SupplierSettlementRequestPayload({
    required this.supplierId,
    required this.amount,
    required this.paymentMethod,
    this.note,
    this.createdBy,
    this.idempotencyKey,
  });

  final String supplierId;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String? createdBy;
  final String? idempotencyKey;
}
