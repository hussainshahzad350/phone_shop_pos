import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_handler.dart';

class PurchaseScannerHandler implements ScannerModeHandler {
  PurchaseScannerHandler({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<ScannerHandlerResult> handle(ScannerScanPayload payload) async {
    final formState = _ref.read(purchaseFormStateProvider);
    final repository = await _ref.read(purchaseRepositoryProvider.future);

    final productsResult =
        await repository.searchProducts(payload.normalizedValue, limit: 10);
    if (productsResult.isFailure) {
      return ScannerHandlerResult(
        isSuccess: false,
        code: 'purchase_scan_lookup_failed',
        message: productsResult.asFailure!.error.message,
      );
    }

    final products = productsResult.asSuccess!.value;
    if (products.isNotEmpty) {
      final product = _selectBestProductMatch(
        payload.normalizedValue,
        products,
      );
      await _ref.read(purchaseFormStateProvider.notifier).addProduct(product);

      if (product.hasImei && payload.isImei) {
        final updatedForm = _ref.read(purchaseFormStateProvider);
        final targetIndex = _findLatestProductIndex(updatedForm.items, product.id);
        if (targetIndex >= 0) {
          final addEntryResult =
              await _ref.read(purchaseFormStateProvider.notifier).addImeiEntry(
                    index: targetIndex,
                    entry: ImeiEntry(
                      imei1: payload.normalizedValue,
                      costPrice: updatedForm.items[targetIndex].unitCost,
                    ),
                  );
          if (addEntryResult.isFailure) {
            return ScannerHandlerResult(
              isSuccess: false,
              code: addEntryResult.asFailure!.error.code,
              message: addEntryResult.asFailure!.error.message,
            );
          }
        }
      }

      return const ScannerHandlerResult(
        isSuccess: true,
        code: 'purchase_scan_added',
        message: 'Scanned item added to purchase form.',
      );
    }

    if (!payload.isImei) {
      return const ScannerHandlerResult(
        isSuccess: false,
        code: 'purchase_scan_not_found',
        message: 'No product found for scanned code in purchases.',
      );
    }

    final serializedIndexes = <int>[];
    for (var i = 0; i < formState.items.length; i++) {
      if (formState.items[i].hasImei) {
        serializedIndexes.add(i);
      }
    }

    if (serializedIndexes.isEmpty) {
      return const ScannerHandlerResult(
        isSuccess: false,
        code: 'purchase_scan_needs_product',
        message: 'Scan a serialized product first, then scan IMEI entries.',
      );
    }

    if (serializedIndexes.length > 1) {
      return const ScannerHandlerResult(
        isSuccess: false,
        code: 'purchase_scan_ambiguous_imei_target',
        message: 'Multiple serialized purchase lines found. Select one manually.',
      );
    }

    final targetIndex = serializedIndexes.single;
    final addEntryResult =
        await _ref.read(purchaseFormStateProvider.notifier).addImeiEntry(
              index: targetIndex,
              entry: ImeiEntry(
                imei1: payload.normalizedValue,
                costPrice: formState.items[targetIndex].unitCost,
              ),
            );

    if (addEntryResult.isFailure) {
      return ScannerHandlerResult(
        isSuccess: false,
        code: addEntryResult.asFailure!.error.code,
        message: addEntryResult.asFailure!.error.message,
      );
    }

    return const ScannerHandlerResult(
      isSuccess: true,
      code: 'purchase_scan_imei_added',
      message: 'Scanned IMEI linked to current purchase item.',
    );
  }

  ProductEntity _selectBestProductMatch(
    String code,
    List<ProductEntity> products,
  ) {
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

  int _findLatestProductIndex(List<PurchaseFormItem> items, String productModelId) {
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i].productModelId == productModelId) {
        return i;
      }
    }
    return -1;
  }
}
