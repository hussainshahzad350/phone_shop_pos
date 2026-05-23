import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';

class SalesScannerHandler implements ScannerModeHandler {
  SalesScannerHandler({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    if (payload.isFinishCode) {
      final cartItems = _ref.read(cartStateProvider);
      if (cartItems.isEmpty) {
        return const ScannerHandlerResult(
          isSuccess: true,
          code: 'sales_finish_scan_empty',
          message: 'Finish scan received, but cart is empty.',
          resetSession: true,
          isWarning: true,
        );
      }
      _ref
          .read(appShortcutEventBusProvider.notifier)
          .emit(AppShortcutEvent.saveOrComplete);
      return const ScannerHandlerResult(
        isSuccess: true,
        code: 'sales_finish_scan',
        message: 'Finish code accepted. Completing sale.',
        resetSession: true,
      );
    }

    final repository = await _ref.read(salesRepositoryProvider.future);
    final productsResult =
        await repository.searchSellableProducts(payload.normalizedValue, limit: 10);
    if (productsResult.isFailure) {
      return ScannerHandlerResult(
        isSuccess: false,
        code: 'sales_scan_lookup_failed',
        message: productsResult.asFailure!.error.message,
      );
    }

    final products = productsResult.asSuccess!.value;
    if (products.isEmpty) {
      return const ScannerHandlerResult(
        isSuccess: false,
        code: 'sales_scan_not_found',
        message: 'No sellable product found for scanned code.',
      );
    }

    final product = _selectBestProductMatch(
      code: payload.normalizedValue,
      products: products,
    );

    SerializedStockEntity? selectedStock;
    if (product.hasImei) {
      final imeiResult = await repository.getAvailableImeis(
        product.id,
        query: payload.normalizedValue,
        limit: 1,
      );
      if (imeiResult.isFailure) {
        return ScannerHandlerResult(
          isSuccess: false,
          code: 'sales_imei_lookup_failed',
          message: imeiResult.asFailure!.error.message,
        );
      }

      final directMatches = imeiResult.asSuccess!.value;
      if (directMatches.isNotEmpty) {
        selectedStock = directMatches.first;
      } else {
        final fallbackResult = await repository.getAvailableImeis(
          product.id,
          limit: 1,
        );
        if (fallbackResult.isFailure) {
          return ScannerHandlerResult(
            isSuccess: false,
            code: 'sales_imei_lookup_failed',
            message: fallbackResult.asFailure!.error.message,
          );
        }
        final fallback = fallbackResult.asSuccess!.value;
        if (fallback.isNotEmpty) {
          selectedStock = fallback.first;
        }
      }

      if (selectedStock == null) {
        return const ScannerHandlerResult(
          isSuccess: false,
          code: 'sales_imei_unavailable',
          message: 'No in-stock IMEI is available for this product.',
        );
      }
    }

    final addResult = await _ref.read(cartStateProvider.notifier).addToCart(
          product: product,
          quantity: 1,
          serializedStockId: selectedStock?.id,
          imei: selectedStock?.imei1,
          price: selectedStock?.sellingPrice ?? product.salePrice,
        );

    if (addResult.isFailure) {
      return ScannerHandlerResult(
        isSuccess: false,
        code: addResult.asFailure!.error.code,
        message: addResult.asFailure!.error.message,
      );
    }

    return const ScannerHandlerResult(
      isSuccess: true,
      code: 'sales_scan_added',
      message: 'Item added to cart from scanner input.',
      activateFastBilling: true,
    );
  }

  ProductEntity _selectBestProductMatch({
    required String code,
    required List<ProductEntity> products,
  }) {
    final lowerCode = code.toLowerCase();
    for (final product in products) {
      if (product.barcode?.trim() == code ||
          product.sku?.trim().toLowerCase() == lowerCode) {
        return product;
      }
    }
    for (final product in products) {
      if (product.name.toLowerCase().startsWith(lowerCode)) {
        return product;
      }
    }
    return products.first;
  }
}
