class RunningBalanceRowEntity {
  const RunningBalanceRowEntity({
    required this.eventId,
    required this.createdAt,
    required this.runningBalance,
  });

  final String eventId;
  final DateTime createdAt;
  final double runningBalance;
}
