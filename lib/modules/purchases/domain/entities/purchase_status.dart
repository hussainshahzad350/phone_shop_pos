enum PurchaseStatus {
  posted('posted'),
  void_('void');

  const PurchaseStatus(this.value);

  final String value;

  static PurchaseStatus fromString(String? value) =>
      value == 'void' ? void_ : posted;
}
