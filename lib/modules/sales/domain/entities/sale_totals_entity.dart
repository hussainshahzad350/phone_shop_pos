class SaleTotalsEntity {
  const SaleTotalsEntity({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
  });

  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;

  double get remaining => total - paidAmount;
}
