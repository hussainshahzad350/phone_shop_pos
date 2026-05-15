import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';

class PurchaseService {
  const PurchaseService({
    required PurchaseRepository repository,
  }) : _repository = repository;

  final PurchaseRepository _repository;

  Result<List<PurchaseFormItem>> addProduct({
    required List<PurchaseFormItem> items,
    required ProductEntity product,
  }) {
    final existing = items.indexWhere(
      (item) => !item.hasImei && item.productModelId == product.id,
    );

    if (!product.hasImei && existing >= 0) {
      final nextItems = <PurchaseFormItem>[...items];
      final current = nextItems[existing];
      nextItems[existing] = current.copyWith(quantity: current.quantity + 1);
      return Success<List<PurchaseFormItem>>(nextItems);
    }

    return Success<List<PurchaseFormItem>>(
      <PurchaseFormItem>[
        ...items,
        PurchaseFormItem(
          productModelId: product.id,
          productName: product.name,
          hasImei: product.hasImei,
          unitCost: product.purchasePrice,
        ),
      ],
    );
  }

  Result<List<PurchaseFormItem>> removeItem({
    required List<PurchaseFormItem> items,
    required int index,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    final nextItems = <PurchaseFormItem>[...items]..removeAt(index);
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Result<List<PurchaseFormItem>> updateQuantity({
    required List<PurchaseFormItem> items,
    required int index,
    required int quantity,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    if (quantity <= 0) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_qty', message: 'Quantity must be greater than 0.'),
      );
    }

    final item = items[index];
    if (item.hasImei) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(
          code: 'serialized_qty_locked',
          message: 'Serialized items use IMEI entries to determine quantity.',
        ),
      );
    }

    final nextItems = <PurchaseFormItem>[...items];
    nextItems[index] = item.copyWith(quantity: quantity);
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Result<List<PurchaseFormItem>> updateUnitCost({
    required List<PurchaseFormItem> items,
    required int index,
    required double cost,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    if (cost < 0) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_cost', message: 'Unit cost cannot be negative.'),
      );
    }

    final nextItems = <PurchaseFormItem>[...items];
    nextItems[index] = items[index].copyWith(unitCost: cost);
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Result<List<PurchaseFormItem>> addImeiEntry({
    required List<PurchaseFormItem> items,
    required int index,
    required ImeiEntry entry,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    final item = items[index];
    if (!item.hasImei) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'not_serialized', message: 'Item does not use IMEI.'),
      );
    }

    final duplicate = item.imeiEntries.any(
      (e) => e.imei1 == entry.imei1,
    );
    if (duplicate) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'duplicate_imei', message: 'This IMEI is already added.'),
      );
    }

    final nextItems = <PurchaseFormItem>[...items];
    nextItems[index] = item.copyWith(
      imeiEntries: <ImeiEntry>[...item.imeiEntries, entry],
    );
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Result<List<PurchaseFormItem>> removeImeiEntry({
    required List<PurchaseFormItem> items,
    required int itemIndex,
    required int imeiIndex,
  }) {
    if (itemIndex < 0 || itemIndex >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    final item = items[itemIndex];
    if (imeiIndex < 0 || imeiIndex >= item.imeiEntries.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_imei_index', message: 'IMEI entry not found.'),
      );
    }

    final nextEntries = <ImeiEntry>[...item.imeiEntries]..removeAt(imeiIndex);
    final nextItems = <PurchaseFormItem>[...items];
    nextItems[itemIndex] = item.copyWith(imeiEntries: nextEntries);
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Future<Result<void>> validateImei({
    required String imei,
    required List<PurchaseFormItem> currentItems,
  }) async {
    final trimmed = imei.trim();
    if (trimmed.isEmpty) {
      return const Failure<void>(
        AppError(code: 'empty_imei', message: 'IMEI cannot be empty.'),
      );
    }

    // Phase 5: IMEI format validation — standard IMEIs are exactly 15 digits.
    if (!RegExp(r'^\d{14,15}$').hasMatch(trimmed)) {
      return const Failure<void>(
        AppError(
          code: 'invalid_imei_format',
          message: 'IMEI must be 14–15 digits with no spaces or hyphens.',
        ),
      );
    }

    // Phase 2: check against both imei1 and imei2 in all current form entries.
    final duplicateInForm = currentItems
        .where((item) => item.hasImei)
        .expand((item) => item.imeiEntries)
        .any((entry) => entry.imei1.trim() == trimmed || entry.imei2?.trim() == trimmed);

    if (duplicateInForm) {
      return const Failure<void>(
        AppError(
          code: 'duplicate_imei_form',
          message: 'This IMEI is already entered in the current purchase.',
        ),
      );
    }

    final dbResult = await _repository.isImeiUnique(trimmed);
    if (dbResult.isFailure) {
      return Failure<void>(dbResult.asFailure!.error);
    }

    if (!(dbResult.asSuccess?.value ?? false)) {
      return const Failure<void>(
        AppError(
          code: 'imei_exists',
          message: 'This IMEI already exists in stock.',
        ),
      );
    }

    return const Success<void>(null);
  }

  Future<Result<PurchaseCompletionEntity>> completePurchase({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
    required double paidAmount,
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  }) async {
    if (items.isEmpty) {
      return const Failure<PurchaseCompletionEntity>(
        AppError(code: 'empty_items', message: 'No items in purchase.'),
      );
    }

    for (final item in items) {
      if (item.hasImei && item.imeiEntries.isEmpty) {
        return Failure<PurchaseCompletionEntity>(
          AppError(
            code: 'missing_imeis',
            message: '${item.productName} has no IMEI entries.',
          ),
        );
      }
      if (!item.hasImei && item.quantity <= 0) {
        return Failure<PurchaseCompletionEntity>(
          AppError(
            code: 'invalid_qty',
            message: '${item.productName} has invalid quantity.',
          ),
        );
      }
    }

    return _repository.createPurchaseTransaction(
      items: items,
      discount: discount,
      tax: tax,
      paidAmount: paidAmount,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      notes: notes,
    );
  }
}
