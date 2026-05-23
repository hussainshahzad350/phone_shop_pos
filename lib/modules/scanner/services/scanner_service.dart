import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_validation_result.dart';

class ScannerService {
  const ScannerService({
    this.finishScanCode = defaultFinishScanCode,
  });

  static const String defaultFinishScanCode = '9999999999999';
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  final String finishScanCode;

  ScannerValidationResult normalizeAndValidate(String rawValue) {
    final sanitizedRaw = rawValue.replaceAll(_controlChars, '');
    final normalized = sanitizedRaw.trim();

    if (normalized.isEmpty) {
      return const ScannerValidationResult.invalid(
        errorCode: 'empty_scan',
        errorMessage: 'Scanner input is empty.',
      );
    }

    if (!_digitsOnly.hasMatch(normalized)) {
      return const ScannerValidationResult.invalid(
        errorCode: 'invalid_scan_format',
        errorMessage: 'Scanner input must be numeric.',
      );
    }

    final isFinishCode = normalized == finishScanCode;
    if (!isFinishCode && (normalized.length < 8 || normalized.length > 20)) {
      return const ScannerValidationResult.invalid(
        errorCode: 'invalid_scan_length',
        errorMessage: 'Barcode/IMEI length must be between 8 and 20 digits.',
      );
    }

    return ScannerValidationResult.valid(
      ScannerScanPayload(
        rawValue: rawValue,
        normalizedValue: normalized,
        receivedAt: DateTime.now().toUtc(),
        isImei: normalized.length == 14 || normalized.length == 15,
        isFinishCode: isFinishCode,
      ),
    );
  }
}
