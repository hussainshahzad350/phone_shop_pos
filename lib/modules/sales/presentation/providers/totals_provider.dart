import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';

final totalsProvider = Provider<SaleTotalsEntity>((ref) {
  final cartItems = ref.watch(cartStateProvider);
  final billingState = ref.watch(billingStateProvider);
  final calculator = ref.watch(salesCalculatorProvider);

  return calculator.calculate(
    items: cartItems,
    discount: billingState.discount,
    tax: billingState.tax,
    paidAmount: billingState.paidAmount,
  );
});
