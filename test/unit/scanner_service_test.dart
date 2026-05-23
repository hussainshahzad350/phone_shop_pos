import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

void main() {
  group('ScannerService', () {
    const service = ScannerService();

    test('accepts IMEI and marks it correctly', () {
      final result = service.normalizeAndValidate('  123456789012345\n');
      expect(result.isValid, isTrue);
      expect(result.payload?.normalizedValue, '123456789012345');
      expect(result.payload?.isImei, isTrue);
      expect(result.payload?.isFinishCode, isFalse);
    });

    test('accepts finish scan code regardless of generic length rule', () {
      final result = service.normalizeAndValidate(ScannerService.defaultFinishScanCode);
      expect(result.isValid, isTrue);
      expect(result.payload?.isFinishCode, isTrue);
    });

    test('rejects non-numeric input', () {
      final result = service.normalizeAndValidate('abc123');
      expect(result.isValid, isFalse);
      expect(result.errorCode, 'invalid_scan_format');
    });

    test('rejects short numeric input', () {
      final result = service.normalizeAndValidate('1234567');
      expect(result.isValid, isFalse);
      expect(result.errorCode, 'invalid_scan_length');
    });
  });
}
