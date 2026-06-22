enum SaleStatus {
  posted('posted'),
  void_('void');

  const SaleStatus(this.value);

  final String value;

  static SaleStatus fromString(String? value) =>
      value == 'void' ? void_ : posted;
}
