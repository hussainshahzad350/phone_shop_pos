class LedgerTimelineQuery {
  const LedgerTimelineQuery({
    this.partyId,
    this.ledgerType,
    this.startDate,
    this.endDate,
    this.outstandingOnly = false,
    this.includePaymentHistory = true,
    this.limit = 300,
    this.offset = 0,
  });

  final String? partyId;
  final String? ledgerType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool outstandingOnly;
  final bool includePaymentHistory;
  final int limit;
  final int offset;
}
