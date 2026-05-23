import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/scanner/controller/scanner_controller.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_router.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

void main() {
  group('ScannerController', () {
    test('blocks duplicate scans in the same session', () async {
      final fakeHandler = _FakeModeHandler(
        result: const ScannerHandlerResult(
          isSuccess: true,
          code: 'ok',
          message: 'ok',
        ),
      );
      final controller = ScannerController(
        scannerService: const ScannerService(),
        modeRouter: ScannerModeRouter(
          salesHandler: fakeHandler,
          purchaseHandler: fakeHandler,
          inventoryHandler: fakeHandler,
        ),
      )..setActiveMode(ScannerMode.sales);

      await controller.submitRawScan('12345678');
      await controller.submitRawScan('12345678');

      expect(fakeHandler.calls, 1);
      expect(controller.state.lastFeedback?.code, 'duplicate_scan');
    });

    test('resets session when handler requests reset (finish flow)', () async {
      final fakeHandler = _FakeModeHandler(
        result: const ScannerHandlerResult(
          isSuccess: true,
          code: 'sales_finish_scan',
          message: 'done',
          resetSession: true,
        ),
      );
      final controller = ScannerController(
        scannerService: const ScannerService(),
        modeRouter: ScannerModeRouter(
          salesHandler: fakeHandler,
          purchaseHandler: fakeHandler,
          inventoryHandler: fakeHandler,
        ),
      )..setActiveMode(ScannerMode.sales);

      await controller.submitRawScan('12345678');
      await controller.submitRawScan(ScannerService.defaultFinishScanCode);

      expect(controller.state.processedValues, isEmpty);
      expect(controller.state.fastBillingActive, isFalse);
    });

    test('activates fast billing state on successful sales scan when enabled', () async {
      final fakeHandler = _FakeModeHandler(
        result: const ScannerHandlerResult(
          isSuccess: true,
          code: 'sales_scan_added',
          message: 'added',
        ),
      );
      final controller = ScannerController(
        scannerService: const ScannerService(),
        modeRouter: ScannerModeRouter(
          salesHandler: fakeHandler,
          purchaseHandler: fakeHandler,
          inventoryHandler: fakeHandler,
        ),
      )..setActiveMode(ScannerMode.sales);

      await controller.submitRawScan('12345678');

      expect(controller.state.fastBillingActive, isTrue);
    });
  });
}

class _FakeModeHandler implements ScannerModeHandler {
  _FakeModeHandler({required this.result});

  final ScannerHandlerResult result;
  int calls = 0;

  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    calls += 1;
    return result;
  }
}
