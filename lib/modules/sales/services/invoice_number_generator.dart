class InvoiceNumberGenerator {
  const InvoiceNumberGenerator();

  String generate({required DateTime date, required int sequence}) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final seq = sequence.toString().padLeft(4, '0');
    return 'INV-$y$m$d-$seq';
  }
}
