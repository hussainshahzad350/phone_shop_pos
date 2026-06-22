import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_state_provider.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_repository_provider.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_header_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_scan_payload.dart';

void main() {
  test('sales scanner handler adds scanned item to cart via service path', () async {
    final product = _buildProduct(id: 'p1', hasImei: false, barcode: '12345678');
    final container = ProviderContainer(
      overrides: <Override>[
        salesRepositoryProvider.overrideWith(
          (ref) async => _FakeSalesRepository(product: product),
        ),
      ],
    );
    addTearDown(container.dispose);

    final handler = container.read(salesScannerHandlerProvider);
    final result = await handler.handle(
      _payload('12345678'),
    );

    expect(result.isSuccess, isTrue);
    expect(container.read(cartStateProvider).length, 1);
  });

  test('purchase scanner handler adds scanned product to purchase form', () async {
    final product = _buildProduct(id: 'p2', hasImei: false, barcode: '23456789');
    final container = ProviderContainer(
      overrides: <Override>[
        purchaseRepositoryProvider.overrideWith(
          (ref) async => _FakePurchaseRepository(product: product),
        ),
      ],
    );
    addTearDown(container.dispose);

    final handler = container.read(purchaseScannerHandlerProvider);
    final result = await handler.handle(_payload('23456789'));

    expect(result.isSuccess, isTrue);
    expect(container.read(purchaseFormStateProvider).items.length, 1);
  });

  test('inventory scanner handler updates inventory search query', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final handler = container.read(inventoryScannerHandlerProvider);
    final result = await handler.handle(_payload('34567890'));

    expect(result.isSuccess, isTrue);
    expect(container.read(inventoryFilterProvider).searchQuery, '34567890');
  });
}

ScannerScanPayload _payload(String value) {
  return ScannerScanPayload(
    rawValue: value,
    normalizedValue: value,
    receivedAt: DateTime.utc(2026, 1, 1),
    isImei: value.length == 14 || value.length == 15,
    isFinishCode: false,
  );
}

ProductEntity _buildProduct({
  required String id,
  required bool hasImei,
  required String barcode,
}) {
  return ProductEntity(
    id: id,
    name: 'Product $id',
    purchasePrice: 100,
    salePrice: 120,
    hasImei: hasImei,
    isActive: true,
    barcode: barcode,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository({required this.product});

  final ProductEntity product;

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    return const Success<List<SerializedStockEntity>>(<SerializedStockEntity>[]);
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    return const Success<int>(10);
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    return const Success<bool>(true);
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
    if (query.trim() == product.barcode) {
      return Success<List<ProductEntity>>(<ProductEntity>[product]);
    }
    return const Success<List<ProductEntity>>(<ProductEntity>[]);
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
  }) async {
    return const Failure<SaleCompletionEntity>(
      AppError(code: 'not_implemented', message: 'not used'),
    );
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
          code: 'fake_sales_guard',
          message: 'Fake sales guard failed: $operation',
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

class _FakePurchaseRepository implements PurchaseRepository {
  _FakePurchaseRepository({required this.product});

  final ProductEntity product;

  @override
  Future<Result<PurchaseCompletionEntity>> createPurchaseTransaction({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
    required double paidAmount,
    String? paymentMethod,
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  }) async {
    return const Success<PurchaseCompletionEntity>(
      PurchaseCompletionEntity(
        purchaseId: 'p',
        total: 0,
        serializedItemCount: 0,
        quantityItemCount: 0,
      ),
    );
  }

  @override
  Future<Result<bool>> isImeiUnique(String imei) async {
    return const Success<bool>(true);
  }

  @override
  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim() == product.barcode) {
      return Success<List<ProductEntity>>(<ProductEntity>[product]);
    }
    return const Success<List<ProductEntity>>(<ProductEntity>[]);
  }

  @override
  Future<Result<List<SupplierOptionEntity>>> searchSuppliers(
    String query, {
    int limit = 20,
  }) async {
    return const Success<List<SupplierOptionEntity>>(<SupplierOptionEntity>[]);
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
          code: 'fake_purchase_guard',
          message: 'Fake purchase guard failed: $operation',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<PurchaseEntity>> getPurchaseById(String purchaseId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> voidPurchase({
    required String purchaseId,
    required String voidReason,
    String? voidedBy,
  }) =>
      throw UnimplementedError();
}
