import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_direction.dart';

class LedgerTimelineRowEntity {
  const LedgerTimelineRowEntity({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.transactionId,
    required this.ledgerType,
    required this.amount,
    required this.direction,
    required this.createdAt,
    required this.runningBalance,
    required this.note,
    required this.isReversal,
    required this.reversalOf,
    required this.paymentMethod,
    required this.sourceLabel,
  });

  final String id;
  final String partyId;
  final String partyName;
  final String transactionId;
  final String ledgerType;
  final double amount;
  final LedgerDirection direction;
  final DateTime createdAt;
  final double runningBalance;
  final String? note;
  final bool isReversal;
  final String? reversalOf;
  final String? paymentMethod;
  final String sourceLabel;
}
