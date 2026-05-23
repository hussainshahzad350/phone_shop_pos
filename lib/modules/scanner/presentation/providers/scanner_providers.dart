import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/modules/scanner/controller/scanner_controller.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_session_state.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_router.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

final scannerServiceProvider = Provider<ScannerService>(
  (ref) => const ScannerService(),
);

final scannerModeRouterProvider = Provider<ScannerModeRouter>((ref) {
  final salesHandler = ref.watch(salesScannerHandlerProvider);
  final purchaseHandler = ref.watch(purchaseScannerHandlerProvider);
  final inventoryHandler = ref.watch(inventoryScannerHandlerProvider);
  return ScannerModeRouter(
    salesHandler: salesHandler,
    purchaseHandler: purchaseHandler,
    inventoryHandler: inventoryHandler,
  );
});

final scannerControllerProvider =
    StateNotifierProvider<ScannerController, ScannerSessionState>((ref) {
  final scannerService = ref.watch(scannerServiceProvider);
  final router = ref.watch(scannerModeRouterProvider);
  return ScannerController(scannerService: scannerService, modeRouter: router);
});

final scannerActiveModeProvider =
    Provider<ScannerMode?>((ref) => ref.watch(scannerControllerProvider).activeMode);
