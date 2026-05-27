class LedgerBalanceSummaryEntity {
  const LedgerBalanceSummaryEntity({
    required this.receivable,
    required this.payable,
    required this.net,
  });

  final double receivable;
  final double payable;
  final double net;
}
