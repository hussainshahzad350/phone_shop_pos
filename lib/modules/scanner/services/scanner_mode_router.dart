import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';

class ScannerModeRouter {
  const ScannerModeRouter({
    required ScannerModeHandler salesHandler,
    required ScannerModeHandler purchaseHandler,
    required ScannerModeHandler inventoryHandler,
  })  : _salesHandler = salesHandler,
        _purchaseHandler = purchaseHandler,
        _inventoryHandler = inventoryHandler;

  final ScannerModeHandler _salesHandler;
  final ScannerModeHandler _purchaseHandler;
  final ScannerModeHandler _inventoryHandler;

  Future<ScannerHandlerResult> route({
    required ScannerMode mode,
    required ScannerScanPayload payload,
  }) {
    switch (mode) {
      case ScannerMode.sales:
        return _salesHandler.handle(payload);
      case ScannerMode.purchase:
        return _purchaseHandler.handle(payload);
      case ScannerMode.inventory:
        return _inventoryHandler.handle(payload);
    }
  }
}
