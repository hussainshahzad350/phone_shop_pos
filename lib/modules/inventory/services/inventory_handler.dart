import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_state_provider.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';

class InventoryScannerHandler implements ScannerModeHandler {
  InventoryScannerHandler({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    _ref.read(inventoryFilterProvider.notifier).setSearch(payload.normalizedValue);
    return const ScannerHandlerResult(
      isSuccess: true,
      code: 'inventory_scan_applied',
      message: 'Inventory search updated from scanner input.',
    );
  }
}
