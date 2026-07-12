import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/imei_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_calculator.dart';

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
        AppError(
            code: 'invalid_qty', message: 'Quantity must be greater than 0.'),
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
        AppError(
            code: 'invalid_cost', message: 'Unit cost cannot be negative.'),
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
      imei1: ImeiHelpers.normalize(entry.imei1),
      imei2: ImeiHelpers.normalizeNullable(entry.imei2),
      serialNumber: _normalizeOptional(entry.serialNumber),
      costPrice: entry.costPrice,
      sellingPrice: entry.sellingPrice,
      condition: entry.condition,
      sellerName: _normalizeOptional(entry.sellerName),
      sellerIdCard: _normalizeOptional(entry.sellerIdCard),
      sellerAddress: _normalizeOptional(entry.sellerAddress),
      remainingWarranty: _normalizeOptional(entry.remainingWarranty),
      accessories: _normalizeOptional(entry.accessories),
      phoneConditionNotes: _normalizeOptional(entry.phoneConditionNotes),
      sellerPhone: _normalizeOptional(entry.sellerPhone),
    );
    final duplicate = item.imeiEntries.any(
      (existingEntry) => _hasImeiConflict(
        existingEntry: existingEntry,
        newEntry: normalizedEntry,
      ),
    );
    if (duplicate) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(
            code: 'duplicate_imei', message: 'This IMEI is already added.'),
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

  Result<List<PurchaseFormItem>> updateImeiEntry({
    required List<PurchaseFormItem> items,
    required int itemIndex,
    required int imeiIndex,
    required ImeiEntry entry,
  }) {
    if (itemIndex < 0 || itemIndex >= items.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }

    final item = items[itemIndex];
    if (!item.hasImei) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'not_serialized', message: 'Item does not use IMEI.'),
      );
    }
    if (imeiIndex < 0 || imeiIndex >= item.imeiEntries.length) {
      return const Failure<List<PurchaseFormItem>>(
        AppError(code: 'invalid_imei_index', message: 'IMEI entry not found.'),
      );
    }

    final normalizedEntry = ImeiEntry(
      imei1: ImeiHelpers.normalize(entry.imei1),
      imei2: ImeiHelpers.normalizeNullable(entry.imei2),
      serialNumber: _normalizeOptional(entry.serialNumber),
      costPrice: entry.costPrice,
      sellingPrice: entry.sellingPrice,
      condition: entry.condition,
      sellerName: _normalizeOptional(entry.sellerName),
      sellerIdCard: _normalizeOptional(entry.sellerIdCard),
      sellerAddress: _normalizeOptional(entry.sellerAddress),
      remainingWarranty: _normalizeOptional(entry.remainingWarranty),
      accessories: _normalizeOptional(entry.accessories),
      phoneConditionNotes: _normalizeOptional(entry.phoneConditionNotes),
      sellerPhone: _normalizeOptional(entry.sellerPhone),
    );

    final nextEntries = <ImeiEntry>[...item.imeiEntries];
    nextEntries[imeiIndex] = normalizedEntry;
    final nextItems = <PurchaseFormItem>[...items];
    nextItems[itemIndex] = item.copyWith(imeiEntries: nextEntries);
    return Success<List<PurchaseFormItem>>(nextItems);
  }

  Future<Result<void>> validateImei({
    required String imei,
    required List<PurchaseFormItem> currentItems,
  }) async {
    final trimmed = ImeiHelpers.normalize(imei);
    if (trimmed.isEmpty) {
      return const Failure<void>(
        AppError(code: 'empty_imei', message: 'IMEI cannot be empty.'),
      );
    }

    // Phase 5: IMEI format validation — standard IMEIs are exactly 15 digits.
    if (!FieldValidators.isValidImei(trimmed)) {
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
        .any((entry) =>
            ImeiHelpers.normalize(entry.imei1) == trimmed ||
            ImeiHelpers.normalizeNullable(entry.imei2) == trimmed);

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

  /// Validates a purchase IMEI entry before it is stored in form state.
  ///
  /// Both IMEI fields are checked for format, uniqueness, distinctness, and
  /// non-negative cost so invalid serialized stock never reaches persistence.
  Future<Result<void>> validateImeiEntry({
    required ImeiEntry entry,
    required List<PurchaseFormItem> currentItems,
  }) async {
    final normalizedImei1 = ImeiHelpers.normalize(entry.imei1);
    final normalizedImei2 = ImeiHelpers.normalizeNullable(entry.imei2);

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
    String? paymentMethod,
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

    final notesError =
        NotesSafety.validate(notes, fieldLabel: 'Purchase notes');
    if (notesError != null) {
      return Failure<PurchaseCompletionEntity>(
        AppError(code: 'invalid_purchase_notes', message: notesError),
      );
    }
    final normalizedNotes = NotesSafety.normalizeNullable(notes);

    // Partial payment (paying less than the total) is only allowed on credit
    // ("udhar") purchases that are tied to a supplier — otherwise the unpaid
    // balance has no party to be owed to. Cash/card/bank must be paid in full.
    final totals = const PurchaseCalculator()
        .calculate(items: items, discount: discount, tax: tax);
    const epsilon = 0.01;
    final isUnderpaid = paidAmount < totals.total - epsilon;
    if (isUnderpaid) {
      final isCredit = paymentMethod == PaymentMethod.credit;
      final hasSupplier = supplierId != null && supplierId.trim().isNotEmpty;
      // Same underlying rule (an unpaid balance is only allowed on a
      // Credit/Udhar purchase tied to a supplier), surfaced as distinct,
      // actionable messages for each way it can be violated.
      if (!isCredit) {
        final nothingPaid = paidAmount <= epsilon;
        return Failure<PurchaseCompletionEntity>(
          AppError(
            code: 'full_payment_required',
            message: nothingPaid
                ? 'Enter the paid amount, or switch to Credit/Udhar with a '
                    'supplier to record a balance.'
                : 'This payment method must be paid in full. Switch to '
                    'Credit/Udhar with a supplier to leave a balance.',
          ),
        );
      }
      if (!hasSupplier) {
        return const Failure<PurchaseCompletionEntity>(
          AppError(
            code: 'credit_requires_supplier',
            message: 'Select a supplier to record a Credit/Udhar purchase '
                'with an outstanding balance.',
          ),
        );
      }
    }

    return _repository.createPurchaseTransaction(
      items: items,
      discount: discount,
      tax: tax,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      notes: normalizedNotes,
    );
  }

  Future<Result<PurchaseEntity>> getPurchaseById(String purchaseId) {
    return _repository.getPurchaseById(purchaseId);
  }

  Future<Result<void>> voidPurchase({
    required String purchaseId,
    required String voidReason,
    String? voidedBy,
  }) async {
    final trimmedReason = voidReason.trim();
    if (trimmedReason.isEmpty) {
      return const Failure<void>(
        AppError(
          code: 'void_reason_required',
          message: 'Please provide a reason for voiding this purchase.',
        ),
      );
    }
    return _repository.voidPurchase(
      purchaseId: purchaseId,
      voidReason: trimmedReason,
      voidedBy: voidedBy,
    );
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static bool _hasImeiConflict({
    required ImeiEntry existingEntry,
    required ImeiEntry newEntry,
  }) {
    final existingImei1 = ImeiHelpers.normalize(existingEntry.imei1);
    final existingImei2 = ImeiHelpers.normalizeNullable(existingEntry.imei2);
    final newImei1 = ImeiHelpers.normalize(newEntry.imei1);
    final newImei2 = ImeiHelpers.normalizeNullable(newEntry.imei2);
    return existingImei1 == newImei1 ||
        existingImei2 == newImei1 ||
        (newImei2 != null &&
            (existingImei1 == newImei2 || existingImei2 == newImei2));
  }
}
