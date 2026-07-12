class BulkImeiImportFailure {
  const BulkImeiImportFailure({required this.imei, required this.reason});

  final String imei;
  final String reason;
}

/// Result of a bulk IMEI import — every line is processed independently, so
/// one bad line never blocks the rest from committing.
class BulkImeiImportSummary {
  const BulkImeiImportSummary({
    required this.totalScanned,
    required this.added,
    required this.duplicates,
    required this.failed,
  });

  final int totalScanned;
  final int added;
  final List<String> duplicates;
  final List<BulkImeiImportFailure> failed;
}
