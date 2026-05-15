import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';

final purchaseTotalsProvider = Provider<({double subtotal, double total})>((ref) {
  final formState = ref.watch(purchaseFormStateProvider);
  final calculator = ref.watch(purchaseCalculatorProvider);
  return calculator.calculate(
    items: formState.items,
    discount: formState.discount,
    tax: formState.tax,
  );
});
