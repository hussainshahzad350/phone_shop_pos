enum ScannerFeedbackSeverity {
  success,
  warning,
  error,
}

class ScannerProcessFeedback {
  const ScannerProcessFeedback({
    required this.code,
    required this.message,
    required this.severity,
    this.processedValue,
  });

  final String code;
  final String message;
  final ScannerFeedbackSeverity severity;
  final String? processedValue;
}
