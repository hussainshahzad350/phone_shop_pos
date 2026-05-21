import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';

class SalesService {
  const SalesService({
    required SalesRepository repository,
  }) : _repository = repository;

  final SalesRepository _repository;

  Result<List<CartItemEntity>> addToCart({
    required List<CartItemEntity> items,
    required ProductEntity product,
    int quantity = 1,
    double? price,
    String? serializedStockId,
    String? imei,
  }) {
    if (product.hasImei) {
      if (serializedStockId == null || serializedStockId.isEmpty) {
        return const Failure<List<CartItemEntity>>(
          AppError(
            code: 'imei_required',
            message: 'Serialized products require IMEI selection.',
          ),
        );
      }

      final duplicate = items.any(
        (item) => item.serializedStockId == serializedStockId,
      );
      if (duplicate) {
        return const Failure<List<CartItemEntity>>(
          AppError(
            code: 'duplicate_imei',
            message: 'This IMEI is already added in cart.',
          ),
        );
      }

      return Success<List<CartItemEntity>>(
        <CartItemEntity>[
          ...items,
          CartItemEntity(
            productModelId: product.id,
            productName: product.name,
            hasImei: true,
            quantity: 1,
            unitPrice: price ?? product.salePrice,
            serializedStockId: serializedStockId,
            imei: imei,
          ),
        ],
      );
    }

    if (quantity <= 0) {
      return const Failure<List<CartItemEntity>>(
        AppError(
            code: 'invalid_qty', message: 'Quantity must be greater than 0.'),
      );
    }

    final nextItems = <CartItemEntity>[...items];
    final index = nextItems.indexWhere(
      (item) => !item.hasImei && item.productModelId == product.id,
    );

    if (index >= 0) {
      final existing = nextItems[index];
      nextItems[index] =
          existing.copyWith(quantity: existing.quantity + quantity);
      return Success<List<CartItemEntity>>(nextItems);
    }

    nextItems.add(
      CartItemEntity(
        productModelId: product.id,
        productName: product.name,
        hasImei: false,
        quantity: quantity,
        unitPrice: price ?? product.salePrice,
      ),
    );
    return Success<List<CartItemEntity>>(nextItems);
  }

  Result<List<CartItemEntity>> removeFromCart({
    required List<CartItemEntity> items,
    required int index,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<CartItemEntity>>(
        AppError(code: 'invalid_index', message: 'Cart item not found.'),
      );
    }

    final nextItems = <CartItemEntity>[...items]..removeAt(index);
    return Success<List<CartItemEntity>>(nextItems);
  }

  Result<List<CartItemEntity>> updateQty({
    required List<CartItemEntity> items,
    required int index,
    required int quantity,
  }) {
    if (index < 0 || index >= items.length) {
      return const Failure<List<CartItemEntity>>(
        AppError(code: 'invalid_index', message: 'Cart item not found.'),
      );
    }

    final item = items[index];
    if (item.hasImei) {
      return const Failure<List<CartItemEntity>>(
        AppError(
          code: 'serialized_qty_locked',
          message: 'Serialized items always have quantity 1.',
        ),
      );
    }

    if (quantity <= 0) {
      return const Failure<List<CartItemEntity>>(
        AppError(
            code: 'invalid_qty', message: 'Quantity must be greater than 0.'),
      );
    }

    final nextItems = <CartItemEntity>[...items];
    nextItems[index] = item.copyWith(quantity: quantity);
    return Success<List<CartItemEntity>>(nextItems);
  }

  Future<Result<void>> validateStock(List<CartItemEntity> items) async {
    for (final item in items) {
      if (item.hasImei) {
        final stockResult = await _repository.isImeiAvailable(
          item.serializedStockId!,
        );

        if (stockResult.isFailure) {
          return Failure<void>(stockResult.asFailure!.error);
        }

        if (!(stockResult.asSuccess?.value ?? false)) {
          return const Failure<void>(
            AppError(
              code: 'imei_unavailable',
              message: 'One or more selected IMEIs are no longer in stock.',
            ),
          );
        }
      } else {
        final qtyResult =
            await _repository.getAvailableQuantity(item.productModelId);
        if (qtyResult.isFailure) {
          return Failure<void>(qtyResult.asFailure!.error);
        }

        final available = qtyResult.asSuccess?.value ?? 0;
        if (available < item.quantity) {
          return Failure<void>(
            AppError(
              code: 'insufficient_stock',
              message:
                  'Insufficient stock for ${item.productName}. Available: $available',
            ),
          );
        }
      }
    }

    return const Success<void>(null);
  }

  Future<Result<SaleCompletionEntity>> completeSale({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) async {
    if (items.isEmpty) {
      return const Failure<SaleCompletionEntity>(
        AppError(code: 'empty_cart', message: 'Cart is empty.'),
      );
    }

    final validationResult = await validateStock(items);
    if (validationResult.isFailure) {
      return Failure<SaleCompletionEntity>(validationResult.asFailure!.error);
    }

    final notesError = NotesSafety.validate(notes, fieldLabel: 'Sale notes');
    if (notesError != null) {
      return Failure<SaleCompletionEntity>(
        AppError(code: 'invalid_sale_notes', message: notesError),
      );
    }
    final normalizedNotes = NotesSafety.normalizeNullable(notes);
    final normalizedPaymentMethod =
        PaymentMethod.normalizeNullable(paymentMethod);
    final isCreditSale = normalizedPaymentMethod == PaymentMethod.credit;
    final normalizedCustomerId = customerId?.trim();
    final isWalkInCustomer = normalizedCustomerId == null ||
        normalizedCustomerId.isEmpty ||
        normalizedCustomerId.toLowerCase() == 'walk_in';
    if (totals.total > 0 && normalizedPaymentMethod == null) {
      return const Failure<SaleCompletionEntity>(
        AppError(
          code: 'payment_method_required',
          message:
              'Payment method is required for completed sales (cash, card, bank, or credit/udhar).',
        ),
      );
    }
    if (isCreditSale && totals.remaining > 0 && isWalkInCustomer) {
      return const Failure<SaleCompletionEntity>(
        AppError(
          code: 'registered_customer_required_for_credit_sale',
          message:
              'Credit sale requires a registered customer. Please select a customer.',
        ),
      );
    }
    if (isWalkInCustomer && totals.remaining > 0) {
      return const Failure<SaleCompletionEntity>(
        AppError(
          code: 'walk_in_requires_full_payment',
          message:
              'Walk-in customer sale must be fully paid. Select a customer to keep pending amount.',
        ),
      );
    }
    if (isCreditSale && totals.paidAmount > 0) {
      return const Failure<SaleCompletionEntity>(
        AppError(
          code: 'credit_method_requires_zero_upfront',
          message:
              'Credit/Udhar method only supports zero upfront payment. Use cash/card/bank for partial upfront payment.',
        ),
      );
    }
    if (paymentMethod != null && normalizedPaymentMethod == null) {
      return const Failure<SaleCompletionEntity>(
        AppError(
          code: 'invalid_payment_method',
          message: 'Payment method must be cash, card, bank, or credit/udhar.',
        ),
      );
    }

    // Invoice number is generated atomically inside the transaction by the
    // repository; no pre-generation here avoids sequence collisions.
    return _repository.createSaleTransaction(
      items: items,
      totals: totals,
      saleDate: DateTime.now().toUtc(),
      customerId: normalizedCustomerId,
      userId: userId,
      paymentMethod: normalizedPaymentMethod,
      notes: normalizedNotes,
    );
  }
}
