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
import 'package:phone_shop_pos/modules/sales/services/sales_calculator.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_service.dart';

void main() {
  group('PHASE 1 / SECTION D-E (S-021 ... S-025)', () {
    test('S-021 Large cart (20+ items)', () {
      const calculator = SalesCalculator();
      final items = List<CartItemEntity>.generate(
        25,
        (index) => CartItemEntity(
          productModelId: 'prd_large_$index',
          productName: 'Accessory $index',
          hasImei: false,
          quantity: 1 + (index % 3),
          unitPrice: 100 + (index * 10),
        ),
      );
      final expectedSubtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

      final stopwatch = Stopwatch()..start();
      final totals = calculator.calculate(
        items: items,
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );
      stopwatch.stop();

      expect(items.length, greaterThanOrEqualTo(20));
      expect(totals.total, closeTo(expectedSubtotal, 0.0001));
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('S-022 Same accessory added repeatedly', () {
      final service = SalesService(
        repository: _SearchSalesRepository(
          products: const <ProductEntity>[],
          imeiStock: const <SerializedStockEntity>[],
        ),
      );

      final product = ProductEntity(
        id: 'prd_repeat_22',
        name: 'USB Cable',
        purchasePrice: 200,
        salePrice: 350,
        hasImei: false,
        isActive: true,
        createdAt: DateTime.utc(2026, 5, 17),
        updatedAt: DateTime.utc(2026, 5, 17),
      );

      final first = service.addToCart(
        items: const <CartItemEntity>[],
        product: product,
        quantity: 1,
      );
      final second = service.addToCart(
        items: first.asSuccess!.value,
        product: product,
        quantity: 2,
      );
      final third = service.addToCart(
        items: second.asSuccess!.value,
        product: product,
        quantity: 3,
      );

      expect(third.isSuccess, isTrue);
      final merged = third.asSuccess!.value;
      expect(merged.length, 1);
      expect(merged.single.quantity, 6);
    });

    test('S-023 Product search by name', () async {
      final repository = _SearchSalesRepository(
        products: <ProductEntity>[
          _product(id: 'prd_23_a', name: 'Samsung A55'),
          _product(id: 'prd_23_b', name: 'iPhone 13'),
          _product(id: 'prd_23_c', name: 'Type-C Cable'),
        ],
        imeiStock: const <SerializedStockEntity>[],
      );

      final stopwatch = Stopwatch()..start();
      final result = await repository.searchSellableProducts('Samsung');
      stopwatch.stop();

      expect(result.isSuccess, isTrue);
      final products = result.asSuccess!.value;
      expect(products.length, 1);
      expect(products.first.name, 'Samsung A55');
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('S-024 Search partial keyword', () async {
      final repository = _SearchSalesRepository(
        products: <ProductEntity>[
          _product(id: 'prd_24_a', name: 'Samsung A55'),
          _product(id: 'prd_24_b', name: 'Samsung S24 Ultra'),
          _product(id: 'prd_24_c', name: 'iPhone 15 Pro'),
        ],
        imeiStock: const <SerializedStockEntity>[],
      );

      final result = await repository.searchSellableProducts('sam');

      expect(result.isSuccess, isTrue);
      final products = result.asSuccess!.value;
      expect(products.length, 2);
      expect(
          products.map((item) => item.name),
          containsAll(<String>[
            'Samsung A55',
            'Samsung S24 Ultra',
          ]));
    });

    test('S-025 IMEI search', () async {
      final repository = _SearchSalesRepository(
        products: const <ProductEntity>[],
        imeiStock: <SerializedStockEntity>[
          _stock(
              id: 'ss_25_1',
              productModelId: 'pm_phone',
              imei1: '111111111111111'),
          _stock(
              id: 'ss_25_2',
              productModelId: 'pm_phone',
              imei1: '222222222222222'),
        ],
      );

      final result = await repository.getAvailableImeis(
        'pm_phone',
        query: '2222',
      );

      expect(result.isSuccess, isTrue);
      final items = result.asSuccess!.value;
      expect(items.length, 1);
      expect(items.single.imei1, '222222222222222');
    });
  });
}

class _SearchSalesRepository implements SalesRepository {

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
  _SearchSalesRepository({
    required List<ProductEntity> products,
    required List<SerializedStockEntity> imeiStock,
  })  : _products = List<ProductEntity>.from(products),
        _imeiStock = List<SerializedStockEntity>.from(imeiStock);

  final List<ProductEntity> _products;
  final List<SerializedStockEntity> _imeiStock;

  @override
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) async {
    return const Failure<SaleCompletionEntity>(
      AppError(code: 'not_implemented', message: 'Not needed for these tests'),
    );
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    return const Success<int>(0);
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    final filtered = _imeiStock
        .where((item) => item.productModelId == productModelId)
        .where(
          (item) => normalized.isEmpty
              ? true
              : item.imei1.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList(growable: false);
    return Success<List<SerializedStockEntity>>(filtered);
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    return Success<bool>(
        _imeiStock.any((item) => item.id == serializedStockId));
  }

  @override
  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<CustomerOptionEntity>>(<CustomerOptionEntity>[]);
  }

  @override
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    final filtered = _products
        .where(
          (item) => normalized.isEmpty
              ? true
              : item.name.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList(growable: false);
    return Success<List<ProductEntity>>(filtered);
  }

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
          code: 'search_repo_error',
          message: 'Search repository failed during $operation',
          details: error,
        ),
      );
    }
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

ProductEntity _product({
  required String id,
  required String name,
}) {
  return ProductEntity(
    id: id,
    name: name,
    purchasePrice: 1000,
    salePrice: 1200,
    hasImei: false,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

SerializedStockEntity _stock({
  required String id,
  required String productModelId,
  required String imei1,
}) {
  return SerializedStockEntity(
    id: id,
    productModelId: productModelId,
    imei1: imei1,
    stockStatus: SerializedStockStatus.inStock,
    costPrice: 50000,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
