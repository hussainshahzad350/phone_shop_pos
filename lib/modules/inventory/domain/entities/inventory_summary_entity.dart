class InventorySummaryEntity {
  const InventorySummaryEntity({
    required this.totalPhones,
    required this.inStockPhones,
    required this.soldPhones,
    required this.reservedPhones,
    required this.totalAccessoryVariants,
    required this.totalAccessoryUnits,
    required this.lowStockCount,
    required this.totalStockValue,
  });

  final int totalPhones;
  final int inStockPhones;
  final int soldPhones;
  final int reservedPhones;
  final int totalAccessoryVariants;
  final int totalAccessoryUnits;
  final int lowStockCount;
  final double totalStockValue;
}
