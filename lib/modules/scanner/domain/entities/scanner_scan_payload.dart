class ScannerScanPayload {
  const ScannerScanPayload({
    required this.rawValue,
    required this.normalizedValue,
    required this.receivedAt,
    required this.isImei,
    required this.isFinishCode,
  });

  final String rawValue;
  final String normalizedValue;
  final DateTime receivedAt;
  final bool isImei;
  final bool isFinishCode;
}
