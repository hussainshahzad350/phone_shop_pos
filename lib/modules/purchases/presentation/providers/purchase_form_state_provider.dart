import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';

class PurchaseFormState {
  const PurchaseFormState({
    this.selectedSupplierId,
    this.supplierSearchQuery = '',
    this.productSearchQuery = '',
    this.items = const <PurchaseFormItem>[],
    this.discount = 0,
    this.tax = 0,
    this.paidAmount = 0,
    this.paymentMethod = 'cash',
    this.invoiceNumber,
    this.notes,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String? selectedSupplierId;
  final String supplierSearchQuery;
  final String productSearchQuery;
  final List<PurchaseFormItem> items;
  final double discount;
  final double tax;
  final double paidAmount;
  final String paymentMethod;
  final String? invoiceNumber;
  final String? notes;
  final bool isSubmitting;
  final String? errorMessage;

  PurchaseFormState copyWith({
    String? selectedSupplierId,
    bool clearSelectedSupplierId = false,
    String? supplierSearchQuery,
    String? productSearchQuery,
    List<PurchaseFormItem>? items,
    double? discount,
    double? tax,
    double? paidAmount,
    String? paymentMethod,
    String? invoiceNumber,
    bool clearInvoiceNumber = false,
    String? notes,
    bool clearNotes = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PurchaseFormState(
      selectedSupplierId: clearSelectedSupplierId
          ? null
          : selectedSupplierId ?? this.selectedSupplierId,
      supplierSearchQuery: supplierSearchQuery ?? this.supplierSearchQuery,
      productSearchQuery: productSearchQuery ?? this.productSearchQuery,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      invoiceNumber:
          clearInvoiceNumber ? null : invoiceNumber ?? this.invoiceNumber,
      notes: clearNotes ? null : notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PurchaseFormStateNotifier extends StateNotifier<PurchaseFormState> {
  PurchaseFormStateNotifier(this._ref) : super(const PurchaseFormState());

  final Ref _ref;

  void setSupplier(String? supplierId) {
    state = state.copyWith(
      selectedSupplierId: supplierId,
      clearSelectedSupplierId: supplierId == null,
    );
  }

  void setSupplierSearchQuery(String value) {
    state = state.copyWith(supplierSearchQuery: value);
  }

  void setProductSearchQuery(String value) {
    state = state.copyWith(productSearchQuery: value);
  }

  Future<void> addProduct(ProductEntity product) async {
    final service = await _ref.read(purchaseServiceProvider.future);

    final result = service.addProduct(
      items: state.items,
      product: product,
    );

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
    }
  }

  Future<void> removeItem(int index) async {
    final service = await _ref.read(purchaseServiceProvider.future);
    final result = service.removeItem(items: state.items, index: index);

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
    }
  }

  Future<void> updateQuantity(
      {required int index, required int quantity}) async {
    final service = await _ref.read(purchaseServiceProvider.future);
    final result = service.updateQuantity(
      items: state.items,
      index: index,
      quantity: quantity,
    );

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
    }
  }

  Future<void> updateUnitCost(
      {required int index, required double cost}) async {
    final service = await _ref.read(purchaseServiceProvider.future);
    final result = service.updateUnitCost(
      items: state.items,
      index: index,
      cost: cost,
    );

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
    }
  }

  Future<Result<void>> addImeiEntry({
    required int index,
    required ImeiEntry entry,
  }) async {
    final service = await _ref.read(purchaseServiceProvider.future);
    final validation = await service.validateImeiEntry(
      entry: entry,
      currentItems: state.items,
    );
    if (validation.isFailure) {
      state = state.copyWith(errorMessage: validation.asFailure!.error.message);
      return Failure<void>(validation.asFailure!.error);
    }
    final result = service.addImeiEntry(
      items: state.items,
      index: index,
      entry: entry,
    );

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
      return const Success<void>(null);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
      return Failure<void>(result.asFailure!.error);
    }
  }

  Future<void> removeImeiEntry({
    required int itemIndex,
    required int imeiIndex,
  }) async {
    final service = await _ref.read(purchaseServiceProvider.future);
    final result = service.removeImeiEntry(
      items: state.items,
      itemIndex: itemIndex,
      imeiIndex: imeiIndex,
    );

    if (result.isSuccess) {
      state = state.copyWith(
          items: result.asSuccess!.value, clearErrorMessage: true);
    } else {
      state = state.copyWith(errorMessage: result.asFailure!.error.message);
    }
  }

  Future<Result<void>> updateImeiEntry({
    required int itemIndex,
    required int imeiIndex,
    required ImeiEntry entry,
  }) async {
    if (itemIndex < 0 || itemIndex >= state.items.length) {
      return const Failure<void>(
        AppError(code: 'invalid_index', message: 'Item not found.'),
      );
    }
    final item = state.items[itemIndex];
    if (imeiIndex < 0 || imeiIndex >= item.imeiEntries.length) {
      return const Failure<void>(
        AppError(code: 'invalid_imei_index', message: 'IMEI entry not found.'),
      );
    }

    final service = await _ref.read(purchaseServiceProvider.future);
    final validationItems = <PurchaseFormItem>[
      for (var i = 0; i < state.items.length; i++)
        if (i == itemIndex)
          state.items[i].copyWith(
            imeiEntries: <ImeiEntry>[
              for (var j = 0; j < item.imeiEntries.length; j++)
                if (j != imeiIndex) item.imeiEntries[j],
            ],
          )
        else
          state.items[i],
    ];
    final validation = await service.validateImeiEntry(
      entry: entry,
      currentItems: validationItems,
    );
    if (validation.isFailure) {
      state = state.copyWith(errorMessage: validation.asFailure!.error.message);
      return Failure<void>(validation.asFailure!.error);
    }

    final result = service.updateImeiEntry(
      items: state.items,
      itemIndex: itemIndex,
      imeiIndex: imeiIndex,
      entry: entry,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        items: result.asSuccess!.value,
        clearErrorMessage: true,
      );
      return const Success<void>(null);
    }

    state = state.copyWith(errorMessage: result.asFailure!.error.message);
    return Failure<void>(result.asFailure!.error);
  }

  void setDiscount(double value) {
    state = state.copyWith(discount: value);
  }

  void setTax(double value) {
    state = state.copyWith(tax: value);
  }

  void setPaidAmount(double value) {
    state = state.copyWith(paidAmount: value);
  }

  void setPaymentMethod(String value) {
    state = state.copyWith(paymentMethod: value);
  }

  void setInvoiceNumber(String? value) {
    state = state.copyWith(
      invoiceNumber: value,
      clearInvoiceNumber: value == null || value.isEmpty,
    );
  }

  void setNotes(String? value) {
    state = state.copyWith(
      notes: value,
      clearNotes: value == null || value.isEmpty,
    );
  }

  void resetForm() {
    state = const PurchaseFormState();
  }

  /// Clears the typed amount inputs (discount, tax, paid, notes) while leaving
  /// the cart, supplier, and invoice untouched. Used when the user navigates
  /// away from the screen so stale amounts don't linger on return.
  void clearPaymentInputs() {
    state = state.copyWith(
      discount: 0,
      tax: 0,
      paidAmount: 0,
      clearNotes: true,
    );
  }
}

final purchaseFormStateProvider =
    StateNotifierProvider<PurchaseFormStateNotifier, PurchaseFormState>(
  (ref) => PurchaseFormStateNotifier(ref),
);
