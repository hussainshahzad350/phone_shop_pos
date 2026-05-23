import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';

class ScannerHandlerResult {
  const ScannerHandlerResult({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.activateFastBilling = false,
    this.resetSession = false,
    this.isWarning = false,
  });

  final bool isSuccess;
  final String code;
  final String message;
  final bool activateFastBilling;
  final bool resetSession;
  final bool isWarning;
}

abstract class ScannerModeHandler {
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload);
}
