import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

void main() {
  group('PHASE 2 Purchases P-047..P-049', () {
    test('P-047 repeated quantity edits settle on the final quantity', () {
      final service = PurchaseService(repository: _FakePurchaseRepository());
      final original = <PurchaseFormItem>[
        const PurchaseFormItem(
          productModelId: 'prd_p047_acc',
          productName: 'P047 Accessory',
          hasImei: false,
          quantity: 1,
          unitCost: 200,
        ),
      ];

      final afterFirst = service.updateQuantity(
        items: original,
        index: 0,
        quantity: 5,
      );
      expect(afterFirst.isSuccess, isTrue);

      final afterSecond = service.updateQuantity(
        items: afterFirst.asSuccess!.value,
        index: 0,
        quantity: 8,
      );
      expect(afterSecond.isSuccess, isTrue);

      final afterThird = service.updateQuantity(
        items: afterSecond.asSuccess!.value,
        index: 0,
        quantity: 9,
      );
      expect(afterThird.isSuccess, isTrue);

      final finalItem = afterThird.asSuccess!.value.single;
      expect(finalItem.quantity, 9);
      expect(finalItem.lineTotal, 1800);
    });

    test('P-048 remove line before save still allows completion', () async {
      final repository = _FakePurchaseRepository();
      final service = PurchaseService(repository: repository);
      final items = <PurchaseFormItem>[
        const PurchaseFormItem(
          productModelId: 'prd_p048_a',
          productName: 'P048 Cable',
          hasImei: false,
          quantity: 2,
          unitCost: 150,
        ),
        const PurchaseFormItem(
          productModelId: 'prd_p048_b',
          productName: 'P048 Charger',
          hasImei: false,
          quantity: 1,
          unitCost: 300,
        ),
      ];

      final afterRemove = service.removeItem(items: items, index: 1);
      expect(afterRemove.isSuccess, isTrue);
      expect(afterRemove.asSuccess!.value.length, 1);

      final completion = await service.completePurchase(
        items: afterRemove.asSuccess!.value,
        discount: 0,
        tax: 0,
        paidAmount: 300,
      );

      expect(completion.isSuccess, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.lastItems?.length, 1);
      expect(repository.lastItems?.single.productName, 'P048 Cable');
    });

    test('P-049 empty purchase save is rejected', () async {
      final repository = _FakePurchaseRepository();
      final service = PurchaseService(repository: repository);

      final result = await service.completePurchase(
        items: const <PurchaseFormItem>[],
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'empty_items');
      expect(repository.createCalls, 0);
    });

    test('serialized IMEI entry can be corrected before save', () {
      final service = PurchaseService(repository: _FakePurchaseRepository());
      final items = <PurchaseFormItem>[
        const PurchaseFormItem(
          productModelId: 'prd_phone',
          productName: 'Phone',
          hasImei: true,
          unitCost: 100000,
          imeiEntries: <ImeiEntry>[
            ImeiEntry(
              imei1: '356789101234561',
              costPrice: 100000,
            ),
          ],
        ),
      ];

      final result = service.updateImeiEntry(
        items: items,
        itemIndex: 0,
        imeiIndex: 0,
        entry: items.single.imeiEntries.single.copyWith(
          imei1: '356789101234579',
          costPrice: 105000,
        ),
      );

      expect(result.isSuccess, isTrue);
      final updated = result.asSuccess!.value.single.imeiEntries.single;
      expect(updated.imei1, '356789101234579');
      expect(updated.costPrice, 105000);
      expect(result.asSuccess!.value.single.lineTotal, 105000);
    });
  });
}

class _FakePurchaseRepository implements PurchaseRepository {
  int createCalls = 0;
  List<PurchaseFormItem>? lastItems;

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
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  }) async {
    createCalls++;
    lastItems = List<PurchaseFormItem>.from(items);
    return const Success<PurchaseCompletionEntity>(
      PurchaseCompletionEntity(
        purchaseId: 'pur_1',
        total: 300,
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
}
