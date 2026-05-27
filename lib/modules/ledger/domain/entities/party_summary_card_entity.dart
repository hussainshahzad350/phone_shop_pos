class PartySummaryCardEntity {
  const PartySummaryCardEntity({
    required this.partyId,
    required this.partyName,
    required this.totalReceivable,
    required this.totalPayable,
    required this.netBalance,
    required this.outstanding,
    required this.lastActivityAt,
  });

  final String partyId;
  final String partyName;
  final double totalReceivable;
  final double totalPayable;
  final double netBalance;
  final double outstanding;
  final DateTime? lastActivityAt;
}
