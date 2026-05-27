enum LedgerDirection {
  debit,
  credit;

  String get value {
    switch (this) {
      case LedgerDirection.debit:
        return 'debit';
      case LedgerDirection.credit:
        return 'credit';
    }
  }

  static LedgerDirection fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'debit':
        return LedgerDirection.debit;
      case 'credit':
        return LedgerDirection.credit;
      default:
        throw StateError('Invalid ledger direction: $value');
    }
  }
}
