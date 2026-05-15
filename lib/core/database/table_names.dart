class TableNames {
  const TableNames._();

  static const String productModels = 'product_models';
  static const String serializedStock = 'serialized_stock';
  static const String inventoryStock = 'inventory_stock';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String purchases = 'purchases';
  static const String purchaseItems = 'purchase_items';
  static const String expenses = 'expenses';
  static const String users = 'users';
  static const String printJobs = 'print_jobs';

  /// Sequence table used for atomic, collision-free invoice number generation.
  static const String invoiceSequences = 'invoice_sequences';
}
