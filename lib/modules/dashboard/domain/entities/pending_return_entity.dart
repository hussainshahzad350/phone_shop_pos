class PendingReturnEntity {
  const PendingReturnEntity({
    required this.saleId,
    required this.invoiceNumber,
    required this.returnDate,
    required this.returnAmount,
  });

  final String saleId;
  final String invoiceNumber;
  final DateTime returnDate;
  final double returnAmount;
}