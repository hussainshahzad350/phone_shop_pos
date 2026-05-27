import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_direction.dart';

class CustomerLedgerEventEntity {
  const CustomerLedgerEventEntity({
    required this.id,
    required this.partyId,
    required this.transactionId,
    required this.ledgerType,
    required this.amount,
    required this.direction,
    required this.createdAt,
    required this.createdBy,
    required this.isReversal,
    required this.reversalOf,
    required this.note,
    required this.paymentMethod,
  });

  final String id;
  final String partyId;
  final String transactionId;
  final String ledgerType;
  final double amount;
  final LedgerDirection direction;
  final DateTime createdAt;
  final String? createdBy;
  final bool isReversal;
  final String? reversalOf;
  final String? note;
  final String? paymentMethod;
}

class SupplierLedgerEventEntity {
  const SupplierLedgerEventEntity({
    required this.id,
    required this.partyId,
    required this.transactionId,
    required this.ledgerType,
    required this.amount,
    required this.direction,
    required this.createdAt,
    required this.createdBy,
    required this.isReversal,
    required this.reversalOf,
    required this.note,
    required this.paymentMethod,
  });

  final String id;
  final String partyId;
  final String transactionId;
  final String ledgerType;
  final double amount;
  final LedgerDirection direction;
  final DateTime createdAt;
  final String? createdBy;
  final bool isReversal;
  final String? reversalOf;
  final String? note;
  final String? paymentMethod;
}
