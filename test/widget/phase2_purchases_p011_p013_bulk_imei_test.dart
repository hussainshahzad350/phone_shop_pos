import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/imei_entry_widget.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

void main() {
  group('PHASE 2 Purchases P-011..P-013', () {
    testWidgets('P-011 Bulk IMEI paste parses mixed line formats correctly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      List<ImeiEntry>? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    captured = await showDialog<List<ImeiEntry>>(
                      context: context,
                      builder: (_) => const ImeiEntryWidget(
                        defaultCostPrice: 1200,
                      ),
                    );
                  },
                  child: const Text('Open Bulk IMEI'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Bulk IMEI'));
      await tester.pumpAndSettle();

      final bulkInputFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Paste IMEIs here',
      );

      await tester.enterText(
        bulkInputFinder,
        '356789101234571\n'
        '356789101234572 / 69,356789101234590\n'
        '356789101234573;356789101234591;SER-573',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Preview: 3 device(s)'), findsOneWidget);
      await tester.tap(find.text('Add 3 Device(s)'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.length, 3);
      expect(captured![0].imei1, '356789101234571');
      expect(captured![0].imei2, isNull);
      expect(captured![1].imei1, '356789101234572');
      expect(captured![1].imei2, '356789101234590');
      expect(captured![2].imei1, '356789101234573');
      expect(captured![2].imei2, '356789101234591');
      expect(captured![2].serialNumber, 'SER-573');
    });

    test('P-012 Bulk duplicate IMEI gives clear duplicate error on add', () {
      const baseItem = PurchaseFormItem(
        productModelId: 'prd_p012_phone',
        productName: 'P012 Phone',
        hasImei: true,
      );

      final service = PurchaseService(
        repository: _StubPurchaseRepository(existingImeis: const <String>{}),
      );

      final first = service.addImeiEntry(
        items: const <PurchaseFormItem>[baseItem],
        index: 0,
        entry: const ImeiEntry(imei1: '356789101234574', costPrice: 50000),
      );
      expect(first.isSuccess, isTrue);

      final second = service.addImeiEntry(
        items: first.asSuccess!.value,
        index: 0,
        entry: const ImeiEntry(imei1: '356789101234574', costPrice: 50000),
      );

      expect(second.isFailure, isTrue);
      expect(second.asFailure?.error.code, 'duplicate_imei');
      expect(second.asFailure?.error.message.toLowerCase(), contains('imei'));
    });

    test('P-013 Bulk paste with existing DB IMEI is blocked safely', () async {
      final repository = _StubPurchaseRepository(
        existingImeis: const <String>{'356789101234575'},
      );
      final service = PurchaseService(repository: repository);

      final result = await service.completePurchase(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_p013_phone',
            productName: 'P013 Phone',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: '356789101234575', costPrice: 49000),
              ImeiEntry(imei1: '356789101234576', costPrice: 49000),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 98000,
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'imei_exists');
      expect(repository.createPurchaseCallCount, 0);
    });
  });
}

class _StubPurchaseRepository implements PurchaseRepository {
  _StubPurchaseRepository({required Set<String> existingImeis})
      : _existingImeis = existingImeis;

  final Set<String> _existingImeis;
  int _createPurchaseCallCount = 0;

  int get createPurchaseCallCount => _createPurchaseCallCount;

  @override
  Future<Result<String>> peekNextInvoiceNumber() async =>
      const Success<String>('PUR-00000000-0001');

  @override
  Future<Result<bool>> isImeiUnique(String imei) async {
    return Success<bool>(!_existingImeis.contains(imei.trim()));
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
    _createPurchaseCallCount++;
    return const Success<PurchaseCompletionEntity>(
      PurchaseCompletionEntity(
        purchaseId: 'pur_stub',
        total: 0,
        serializedItemCount: 0,
        quantityItemCount: 0,
      ),
    );
  }

  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async {
    final value = await action();
    return Success<T>(value);
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
