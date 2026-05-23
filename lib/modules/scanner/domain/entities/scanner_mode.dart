enum ScannerMode {
  sales,
  purchase,
  inventory,
}

extension ScannerModePath on ScannerMode {
  static ScannerMode? fromPath(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized == '/sales' || normalized.startsWith('/sales/')) {
      return ScannerMode.sales;
    }
    if (normalized == '/purchases' || normalized.startsWith('/purchases/')) {
      return ScannerMode.purchase;
    }
    if (normalized == '/inventory' || normalized.startsWith('/inventory/')) {
      return ScannerMode.inventory;
    }
    return null;
  }
}
