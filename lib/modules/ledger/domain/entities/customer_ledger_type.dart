enum CustomerLedgerType {
  sale,
  salePayment,
  saleReturn,
  repairDue,
  repairPayment,
  usedPhoneBuy,
  usedPhonePayment,
  advanceReceive,
  advanceUse,
  advanceAdjust,
  manualSettlement,
  reversal;

  String get value {
    switch (this) {
      case CustomerLedgerType.sale:
        return 'sale';
      case CustomerLedgerType.salePayment:
        return 'sale_payment';
      case CustomerLedgerType.saleReturn:
        return 'sale_return';
      case CustomerLedgerType.repairDue:
        return 'repair_due';
      case CustomerLedgerType.repairPayment:
        return 'repair_payment';
      case CustomerLedgerType.usedPhoneBuy:
        return 'used_phone_buy';
      case CustomerLedgerType.usedPhonePayment:
        return 'used_phone_payment';
      case CustomerLedgerType.advanceReceive:
        return 'advance_receive';
      case CustomerLedgerType.advanceUse:
        return 'advance_use';
      case CustomerLedgerType.advanceAdjust:
        return 'advance_adjust';
      case CustomerLedgerType.manualSettlement:
        return 'manual_settlement';
      case CustomerLedgerType.reversal:
        return 'reversal';
    }
  }

  static CustomerLedgerType fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'sale':
        return CustomerLedgerType.sale;
      case 'sale_payment':
        return CustomerLedgerType.salePayment;
      case 'sale_return':
        return CustomerLedgerType.saleReturn;
      case 'repair_due':
        return CustomerLedgerType.repairDue;
      case 'repair_payment':
        return CustomerLedgerType.repairPayment;
      case 'used_phone_buy':
        return CustomerLedgerType.usedPhoneBuy;
      case 'used_phone_payment':
        return CustomerLedgerType.usedPhonePayment;
      case 'advance_receive':
        return CustomerLedgerType.advanceReceive;
      case 'advance_use':
        return CustomerLedgerType.advanceUse;
      case 'advance_adjust':
        return CustomerLedgerType.advanceAdjust;
      case 'manual_settlement':
        return CustomerLedgerType.manualSettlement;
      case 'reversal':
        return CustomerLedgerType.reversal;
      default:
        throw StateError('Invalid customer ledger type: $value');
    }
  }
}
