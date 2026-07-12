import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/imei_trace_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_header_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';

void main() {
  test('availableImeisProvider disposes idle family instances and reloads later',
      () async {
    final fakeRepository = _FakeSalesRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        salesRepositoryProvider.overrideWith((ref) async => fakeRepository),
      ],
    );
    addTearDown(container.dispose);

    final firstSub = container.listen<AsyncValue<List<SerializedStockEntity>>>(
      availableImeisProvider('prd_1'),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(availableImeisProvider('prd_1').future);
    expect(fakeRepository.calls, 1);

    firstSub.close();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final secondSub = container.listen<AsyncValue<List<SerializedStockEntity>>>(
      availableImeisProvider('prd_1'),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(availableImeisProvider('prd_1').future);
    expect(fakeRepository.calls, 1);

    secondSub.close();
    await Future<void>.delayed(const Duration(seconds: 21));

    final thirdSub = container.listen<AsyncValue<List<SerializedStockEntity>>>(
      availableImeisProvider('prd_1'),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(availableImeisProvider('prd_1').future);
    expect(fakeRepository.calls, 2);
    thirdSub.close();
  });
}

class _FakeSalesRepository implements SalesRepository {

  @override
  Future<Result<Map<String, String>>> getSupplierNames(
    List<String> supplierIds,
  ) async {
    return const Success<Map<String, String>>(<String, String>{});
  }

  @override
  Future<Result<ImeiTraceEntity?>> getImeiTrace(String imei) async {
    return const Success<ImeiTraceEntity?>(null);
  }
  int calls = 0;

  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async {
    try {
      final value = await action();
      return Success<T>(value);
    } catch (error) {
      return Failure<T>(
        AppError(
          code: 'test_error',
          message: 'Fake repository error during $operation',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    calls++;
    return Success<List<SerializedStockEntity>>(
      <SerializedStockEntity>[
        SerializedStockEntity(
          id: 'ser_1',
          productModelId: productModelId,
          imei1: '356789101234501',
          stockStatus: SerializedStockStatus.inStock,
          costPrice: 50000,
          createdAt: DateTime.utc(2026, 5, 16),
          updatedAt: DateTime.utc(2026, 5, 16),
        ),
      ],
    );
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<SaleHeaderEntity>> getSaleById(String saleId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> voidSale({
    required String saleId,
    required String voidReason,
    String? voidedBy,
  }) =>
      throw UnimplementedError();
}
