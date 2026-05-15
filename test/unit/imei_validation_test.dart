// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/repositories/purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

/// Minimal stub that records DB-lookup calls for IMEI uniqueness.
class _StubPurchaseRepository implements PurchaseRepository {
  _StubPurchaseRepository({required Set<String> existingImeis})
      : _existingImeis = existingImeis;

  final Set<String> _existingImeis;

  @override
  Future<Result<bool>> isImeiUnique(String imei) async =>
      Success<bool>(!_existingImeis.contains(imei));

  // ── Unused stubs ─────────────────────────────────────────────────────────
  @override
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String operation = 'repository_operation',
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    int limit = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<List<SupplierOptionEntity>>> searchSuppliers(
    String query, {
    int limit = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<PurchaseCompletionEntity>> createPurchaseTransaction({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
    required double paidAmount,
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('PurchaseService — IMEI validation', () {
    late PurchaseService service;

    setUp(() {
      service = PurchaseService(
        repository: _StubPurchaseRepository(existingImeis: {'999888777666555'}),
      );
    });

    test('rejects empty IMEI', () async {
      final result = await service.validateImei(
        imei: '',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isFailure, isTrue);
      expect((result.asFailure!.error).code, 'empty_imei');
    });

    test('rejects IMEI shorter than 14 digits', () async {
      final result = await service.validateImei(
        imei: '12345',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isFailure, isTrue);
      expect(
        (result.asFailure!.error).code,
        'invalid_imei_format',
      );
    });

    test('rejects IMEI with non-digit characters', () async {
      final result = await service.validateImei(
        imei: '35678910ABCD123',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isFailure, isTrue);
      expect(
        (result.asFailure!.error).code,
        'invalid_imei_format',
      );
    });

    test('accepts valid 15-digit IMEI not in DB', () async {
      final result = await service.validateImei(
        imei: '356789101234561',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isSuccess, isTrue);
    });

    test('accepts valid 14-digit IMEI not in DB', () async {
      final result = await service.validateImei(
        imei: '35678910123456',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isSuccess, isTrue);
    });

    test('rejects IMEI already in database', () async {
      final result = await service.validateImei(
        imei: '999888777666555',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isFailure, isTrue);
      expect((result.asFailure!.error).code, 'imei_exists');
    });

    test('rejects IMEI duplicate in current form (imei1)', () async {
      const existingEntry = ImeiEntry(
        imei1: '356789101234561',
        costPrice: 1000,
      );
      const item = PurchaseFormItem(
        productModelId: 'prd-001',
        productName: 'Test Phone',
        hasImei: true,
        imeiEntries: <ImeiEntry>[existingEntry],
      );

      final result = await service.validateImei(
        imei: '356789101234561',
        currentItems: <PurchaseFormItem>[item],
      );
      expect(result.isFailure, isTrue);
      expect(
        (result.asFailure!.error).code,
        'duplicate_imei_form',
      );
    });

    test('rejects IMEI duplicate in current form (imei2 cross-field)',
        () async {
      const existingEntry = ImeiEntry(
        imei1: '356789101234561',
        imei2: '356789101234562',
        costPrice: 1000,
      );
      const item = PurchaseFormItem(
        productModelId: 'prd-001',
        productName: 'Test Phone',
        hasImei: true,
        imeiEntries: <ImeiEntry>[existingEntry],
      );

      // Trying to add the same value that is used as imei2 of another entry.
      final result = await service.validateImei(
        imei: '356789101234562',
        currentItems: <PurchaseFormItem>[item],
      );
      expect(result.isFailure, isTrue);
      expect(
        (result.asFailure!.error).code,
        'duplicate_imei_form',
      );
    });

    test('trims whitespace from IMEI before validation', () async {
      // DB already has '999888777666555'; passing with spaces should still fail.
      final result = await service.validateImei(
        imei: '  999888777666555  ',
        currentItems: const <PurchaseFormItem>[],
      );
      expect(result.isFailure, isTrue);
      expect((result.asFailure!.error).code, 'imei_exists');
    });
  });

  group('PurchaseService — addImeiEntry duplicate detection', () {
    late PurchaseService service;

    setUp(() {
      service = PurchaseService(
        repository: _StubPurchaseRepository(existingImeis: <String>{}),
      );
    });

    test('prevents adding duplicate imei1 within same item', () {
      const entry = ImeiEntry(imei1: '356789101234561', costPrice: 1000);
      const item = PurchaseFormItem(
        productModelId: 'prd-001',
        productName: 'Test Phone',
        hasImei: true,
        imeiEntries: <ImeiEntry>[entry],
      );

      final result = service.addImeiEntry(
        items: <PurchaseFormItem>[item],
        index: 0,
        entry: entry, // same imei1
      );
      expect(result.isFailure, isTrue);
      expect((result.asFailure!.error).code, 'duplicate_imei');
    });
  });

  group('PaymentMethod constants', () {
    test('default value is cash', () {
      expect(PaymentMethod.cash, 'cash');
    });

    test('isValid returns true for known methods', () {
      expect(PaymentMethod.isValid('cash'), isTrue);
      expect(PaymentMethod.isValid('card'), isTrue);
      expect(PaymentMethod.isValid('bank'), isTrue);
    });

    test('isValid returns false for unknown methods', () {
      expect(PaymentMethod.isValid('paypal'), isFalse);
      expect(PaymentMethod.isValid(null), isFalse);
      expect(PaymentMethod.isValid(''), isFalse);
    });

    test('values list has exactly 3 entries', () {
      expect(PaymentMethod.values.length, 3);
    });

    test('labels map covers all values', () {
      for (final v in PaymentMethod.values) {
        expect(PaymentMethod.labels.containsKey(v), isTrue);
      }
    });
  });
}
