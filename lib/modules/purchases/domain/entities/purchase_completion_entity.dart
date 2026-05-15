class PurchaseCompletionEntity {
  const PurchaseCompletionEntity({
    required this.purchaseId,
    required this.total,
    required this.serializedItemCount,
    required this.quantityItemCount,
    this.invoiceNumber,
  });

  final String purchaseId;
  final String? invoiceNumber;
  final double total;
  final int serializedItemCount;
  final int quantityItemCount;
}
