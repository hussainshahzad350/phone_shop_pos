import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_header_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/services/sales_service.dart';

void main() {
  test('SalesService rejects completion when paid amount is zero', () async {
    final repository = _FakeSalesRepository();
    final service = SalesService(repository: repository);

    final result = await service.completeSale(
      items: const <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_1',
          productName: 'Cable',
          hasImei: false,
          quantity: 1,
          unitPrice: 500,
        ),
      ],
      totals: const SaleTotalsEntity(
        subtotal: 500,
        discount: 0,
        tax: 0,
        total: 500,
        paidAmount: 0,
      ),
      paymentMethod: 'cash',
    );

    expect(result.isFailure, isTrue);
    expect(result.asFailure?.error.code, 'walk_in_requires_full_payment');
    expect(repository.createCalls, 0);
  });

  test('SalesService rejects notes above max length', () async {
    final repository = _FakeSalesRepository();
    final service = SalesService(repository: repository);
    final notes = 'x' * (NotesSafety.maxLength + 1);

    final result = await service.completeSale(
      items: const <CartItemEntity>[
        CartItemEntity(
          productModelId: 'prd_1',
          productName: 'Cable',
          hasImei: false,
          quantity: 1,
          unitPrice: 500,
        ),
      ],
      totals: const SaleTotalsEntity(
        subtotal: 500,
        discount: 0,
        tax: 0,
        total: 500,
        paidAmount: 500,
      ),
      notes: notes,
    );

    expect(result.isFailure, isTrue);
    expect(repository.createCalls, 0);
  });

  test('PurchaseService trims valid notes and rejects over-limit input',
      () async {
    final repository = _FakePurchaseRepository();
    final service = PurchaseService(repository: repository);

    final successResult = await service.completePurchase(
      items: const <PurchaseFormItem>[
        PurchaseFormItem(
          productModelId: 'prd_1',
          productName: 'Cable',
          hasImei: false,
          quantity: 2,
          unitCost: 200,
        ),
      ],
      discount: 0,
      tax: 0,
      paidAmount: 400,
      notes: '  safe note  ',
    );
    expect(successResult.isSuccess, isTrue);
    expect(repository.capturedNotes, 'safe note');

    final tooLong = await service.completePurchase(
      items: const <PurchaseFormItem>[
        PurchaseFormItem(
          productModelId: 'prd_1',
          productName: 'Cable',
          hasImei: false,
          quantity: 1,
          unitCost: 200,
        ),
      ],
      discount: 0,
      tax: 0,
      paidAmount: 200,
      notes: 'y' * (NotesSafety.maxLength + 1),
    );
    expect(tooLong.isFailure, isTrue);
  });
}

class _FakeSalesRepository implements SalesRepository {
  int createCalls = 0;

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
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  }) async {
    createCalls++;
    return Success<SaleCompletionEntity>(
      SaleCompletionEntity(
        saleId: 'sale_1',
        invoiceNumber: 'INV-1',
        totals: totals,
      ),
    );
  }

  @override
  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  }) async {
    return const Success<List<SerializedStockEntity>>(
        <SerializedStockEntity>[]);
  }

  @override
  Future<Result<int>> getAvailableQuantity(String productModelId) async {
    return const Success<int>(999);
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
    return const Success<List<ProductEntity>>(<ProductEntity>[]);
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
  String? capturedNotes;

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
    capturedNotes = notes;
    return const Success<PurchaseCompletionEntity>(
      PurchaseCompletionEntity(
        purchaseId: 'pur_1',
        total: 400,
        serializedItemCount: 0,
        quantityItemCount: 1,
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
