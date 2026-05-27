enum SupplierLedgerType {
  purchase,
  purchasePayment,
  purchaseReturn,
  advanceReceive,
  advanceAdjust,
  manualSettlement,
  reversal;

  String get value {
    switch (this) {
      case SupplierLedgerType.purchase:
        return 'purchase';
      case SupplierLedgerType.purchasePayment:
        return 'purchase_payment';
      case SupplierLedgerType.purchaseReturn:
        return 'purchase_return';
      case SupplierLedgerType.advanceReceive:
        return 'advance_receive';
      case SupplierLedgerType.advanceAdjust:
        return 'advance_adjust';
      case SupplierLedgerType.manualSettlement:
        return 'manual_settlement';
      case SupplierLedgerType.reversal:
        return 'reversal';
    }
  }

  static SupplierLedgerType fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'purchase':
        return SupplierLedgerType.purchase;
      case 'purchase_payment':
        return SupplierLedgerType.purchasePayment;
      case 'purchase_return':
        return SupplierLedgerType.purchaseReturn;
      case 'advance_receive':
        return SupplierLedgerType.advanceReceive;
      case 'advance_adjust':
        return SupplierLedgerType.advanceAdjust;
      case 'manual_settlement':
        return SupplierLedgerType.manualSettlement;
      case 'reversal':
        return SupplierLedgerType.reversal;
      default:
        throw StateError('Invalid supplier ledger type: $value');
    }
  }
}
