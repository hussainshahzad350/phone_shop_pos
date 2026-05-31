import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';

class CartStateNotifier extends StateNotifier<List<CartItemEntity>> {
  CartStateNotifier(this._ref) : super(const <CartItemEntity>[]);

  final Ref _ref;

  Future<Result<void>> addToCart({
    required ProductEntity product,
    int quantity = 1,
    double? price,
    String? serializedStockId,
    String? imei,
    String? imei2,
    String? serialNumber,
  }) async {
    final service = await _ref.read(salesServiceProvider.future);
    final result = service.addToCart(
      items: state,
      product: product,
      quantity: quantity,
      price: price,
      serializedStockId: serializedStockId,
      imei: imei,
      imei2: imei2,
      serialNumber: serialNumber,
    );

    if (result.isSuccess) {
      state = result.asSuccess!.value;
      return const Success<void>(null);
    }

    return Failure<void>(result.asFailure!.error);
  }

  Future<Result<void>> removeFromCart(int index) async {
    final service = await _ref.read(salesServiceProvider.future);
    final result = service.removeFromCart(items: state, index: index);

    if (result.isSuccess) {
      state = result.asSuccess!.value;
      return const Success<void>(null);
    }

    return Failure<void>(result.asFailure!.error);
  }

  Future<Result<void>> updateQty(
      {required int index, required int quantity}) async {
    final service = await _ref.read(salesServiceProvider.future);
    final result =
        service.updateQty(items: state, index: index, quantity: quantity);

    if (result.isSuccess) {
      state = result.asSuccess!.value;
      return const Success<void>(null);
    }

    return Failure<void>(result.asFailure!.error);
  }

  Future<Result<void>> updateUnitPrice({
    required int index,
    required double price,
  }) async {
    final service = await _ref.read(salesServiceProvider.future);
    final result = service.updateUnitPrice(
      items: state,
      index: index,
      price: price,
    );

    if (result.isSuccess) {
      state = result.asSuccess!.value;
      return const Success<void>(null);
    }

    return Failure<void>(result.asFailure!.error);
  }

  Future<Result<void>> validateStock() async {
    final service = await _ref.read(salesServiceProvider.future);
    return service.validateStock(state);
  }

  Future<Result<SaleCompletionEntity>> completeSale({
    required SaleTotalsEntity totals,
    String? customerId,
    String? paymentMethod,
    String? notes,
  }) async {
    final service = await _ref.read(salesServiceProvider.future);
    final result = await service.completeSale(
      items: state,
      totals: totals,
      customerId: customerId,
      paymentMethod: paymentMethod,
      notes: notes,
    );

    if (result.isSuccess) {
      state = const <CartItemEntity>[];
    }

    return result;
  }

  void clearCart() {
    state = const <CartItemEntity>[];
  }
}

final cartStateProvider =
    StateNotifierProvider<CartStateNotifier, List<CartItemEntity>>(
  (ref) => CartStateNotifier(ref),
);
