import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';

class BillingState {
  BillingState({
    this.productSearchQuery = '',
    this.customerSearchQuery = '',
    this.selectedCustomerId,
    this.discount = 0,
    this.tax = 0,
    this.paidAmount = 0,
    String? paymentMethod,
    this.notes = '',
  }) : paymentMethod = PaymentMethod.normalizeOrDefault(
         paymentMethod ?? PaymentMethod.cash,
       );

  final String productSearchQuery;
  final String customerSearchQuery;
  final String? selectedCustomerId;
  final double discount;
  final double tax;
  final double paidAmount;
  final String paymentMethod;
  final String notes;

  BillingState copyWith({
    String? productSearchQuery,
    String? customerSearchQuery,
    String? selectedCustomerId,
    bool clearSelectedCustomerId = false,
    double? discount,
    double? tax,
    double? paidAmount,
    String? paymentMethod,
    String? notes,
  }) {
    return BillingState(
      productSearchQuery: productSearchQuery ?? this.productSearchQuery,
      customerSearchQuery: customerSearchQuery ?? this.customerSearchQuery,
      selectedCustomerId: clearSelectedCustomerId
          ? null
          : selectedCustomerId ?? this.selectedCustomerId,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
    );
  }
}

class BillingStateNotifier extends StateNotifier<BillingState> {
  BillingStateNotifier() : super(BillingState());

  void setProductSearchQuery(String value) {
    state = state.copyWith(productSearchQuery: value);
  }

  void setCustomerSearchQuery(String value) {
    state = state.copyWith(customerSearchQuery: value);
  }

  void setSelectedCustomerId(String? value) {
    state = state.copyWith(
      selectedCustomerId: value,
      clearSelectedCustomerId: value == null,
    );
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
    state = state.copyWith(
      paymentMethod: PaymentMethod.normalizeOrDefault(value),
    );
  }

  void setNotes(String value) {
    state = state.copyWith(notes: value);
  }

  void resetAfterSale() {
    state = BillingState();
  }

  /// Clears the typed amount inputs (discount, tax, paid, notes) while leaving
  /// the cart, customer, and payment method untouched. Used when the user
  /// navigates away from the screen so stale amounts don't linger on return.
  void clearPaymentInputs() {
    state = state.copyWith(
      discount: 0,
      tax: 0,
      paidAmount: 0,
      notes: '',
    );
  }
}

final billingStateProvider = StateNotifierProvider<BillingStateNotifier, BillingState>(
  (ref) => BillingStateNotifier(),
);
