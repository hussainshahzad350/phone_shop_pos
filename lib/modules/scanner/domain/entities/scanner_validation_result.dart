import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';

class ScannerValidationResult {
  const ScannerValidationResult._({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.payload,
  });

  const ScannerValidationResult.valid(ScannerScanPayload payload)
      : this._(isValid: true, payload: payload);

  const ScannerValidationResult.invalid({
    required String errorCode,
    required String errorMessage,
  }) : this._(
          isValid: false,
          errorCode: errorCode,
          errorMessage: errorMessage,
        );

  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final ScannerScanPayload? payload;
}
