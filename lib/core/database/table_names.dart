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
  static const String brands = 'brands';
  static const String appSettings = 'app_settings';
  static const String salePayments = 'sale_payments';
  static const String saleReturns = 'sale_returns';
  static const String stockAdjustments = 'stock_adjustments';

  static const String repairJobs = 'repair_jobs';

  /// Sequence table used for atomic, collision-free invoice number generation.
  static const String invoiceSequences = 'invoice_sequences';
}
