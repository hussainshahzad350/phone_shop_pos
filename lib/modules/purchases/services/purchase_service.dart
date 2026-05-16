import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';

class PurchaseService {
  const PurchaseService({
    required PurchaseRepository repository,
  }) : _repository = repository;

  static final RegExp _imeiPattern = RegExp(r'^\d{14,15}$');

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

    final normalizedEntry = ImeiEntry(
      imei1: entry.imei1.trim(),
      imei2: _normalizeOptional(entry.imei2),
      serialNumber: _normalizeOptional(entry.serialNumber),
      costPrice: entry.costPrice,
      sellingPrice: entry.sellingPrice,
    );
    final duplicate = item.imeiEntries.any(
      (e) =>
          e.imei1.trim() == normalizedEntry.imei1 ||
          e.imei2?.trim() == normalizedEntry.imei1 ||
          (normalizedEntry.imei2 != null &&
              (e.imei1.trim() == normalizedEntry.imei2 ||
                  e.imei2?.trim() == normalizedEntry.imei2)),
    );
    if (duplicate) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'duplicate_imei', message: 'This IMEI is already added.'),
      );
    }

    final nextItems = <PurchaseFormItem>[...items];
    nextItems[index] = item.copyWith(
      imeiEntries: <ImeiEntry>[...item.imeiEntries, normalizedEntry],
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
    if (!_imeiPattern.hasMatch(trimmed)) {
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

  Future<Result<void>> validateImeiEntry({
    required ImeiEntry entry,
    required List<PurchaseFormItem> currentItems,
  }) async {
    final normalizedImei1 = entry.imei1.trim();
    final normalizedImei2 = entry.imei2?.trim();

    final imei1Result = await validateImei(
      imei: normalizedImei1,
      currentItems: currentItems,
    );
    if (imei1Result.isFailure) {
      return imei1Result;
    }

    if (normalizedImei2 != null && normalizedImei2.isNotEmpty) {
      if (normalizedImei1 == normalizedImei2) {
        return const Failure<void>(
          AppError(
            code: 'duplicate_imei_pair',
            message: 'IMEI 1 and IMEI 2 must be different.',
          ),
        );
      }
      final imei2Result = await validateImei(
        imei: normalizedImei2,
        currentItems: currentItems,
      );
      if (imei2Result.isFailure) {
        return imei2Result;
      }
    }

    if (entry.costPrice < 0) {
      return const Failure<void>(
        AppError(
          code: 'invalid_cost',
          message: 'IMEI cost price cannot be negative.',
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
      if (item.hasImei) {
        final otherItems = items
            .where((current) => !identical(current, item))
            .toList(growable: false);
        for (final entry in item.imeiEntries) {
          final validation = await validateImeiEntry(
            entry: entry,
            currentItems: <PurchaseFormItem>[
              ...otherItems,
              item.copyWith(
                imeiEntries: item.imeiEntries
                    .where((candidate) => !identical(candidate, entry))
                    .toList(growable: false),
              ),
            ],
          );
          if (validation.isFailure) {
            return Failure<PurchaseCompletionEntity>(
              validation.asFailure!.error,
            );
          }
        }
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

    final notesError = NotesSafety.validate(notes, fieldLabel: 'Purchase notes');
    if (notesError != null) {
      return Failure<PurchaseCompletionEntity>(
        AppError(code: 'invalid_purchase_notes', message: notesError),
      );
    }
    final normalizedNotes = NotesSafety.normalizeNullable(notes);

    return _repository.createPurchaseTransaction(
      items: items,
      discount: discount,
      tax: tax,
      paidAmount: paidAmount,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      notes: normalizedNotes,
    );
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
