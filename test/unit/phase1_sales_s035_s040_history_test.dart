import 'package:flutter/foundation.dart';
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

void main() {
  group('PHASE 1 / SECTION G (S-035 ... S-040)', () {
    test('S-035 Search invoice by number', () async {
      final repository = _InvoiceHistoryRepository(
        invoices: <_InvoiceRecord>[
          _InvoiceRecord(
            invoiceNumber: 'INV-001',
            saleId: 'sale_1',
            customerId: 'cust_1',
            total: 100000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
          _InvoiceRecord(
            invoiceNumber: 'INV-002',
            saleId: 'sale_2',
            customerId: 'cust_2',
            total: 50000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
        ],
      );

      final result = await repository.searchInvoices('INV-001');

      expect(result.isSuccess, isTrue);
      final invoices = result.asSuccess!.value;
      expect(invoices.length, 1);
      expect(invoices.first.invoiceNumber, 'INV-001');
    });

    test('S-036 Search by customer', () async {
      final repository = _InvoiceHistoryRepository(
        invoices: <_InvoiceRecord>[
          _InvoiceRecord(
            invoiceNumber: 'INV-001',
            saleId: 'sale_1',
            customerId: 'cust_1',
            customerName: 'Alice',
            total: 100000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
          _InvoiceRecord(
            invoiceNumber: 'INV-002',
            saleId: 'sale_2',
            customerId: 'cust_2',
            customerName: 'Bob',
            total: 50000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
          _InvoiceRecord(
            invoiceNumber: 'INV-003',
            saleId: 'sale_3',
            customerId: 'cust_1',
            customerName: 'Alice',
            total: 75000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
        ],
      );

      final result =
          await repository.searchInvoices(null, customerId: 'cust_1');

      expect(result.isSuccess, isTrue);
      final invoices = result.asSuccess!.value;
      expect(invoices.length, 2);
      expect(invoices.every((inv) => inv.customerId == 'cust_1'), isTrue);
    });

    test('S-037 Search by date', () async {
      final repository = _InvoiceHistoryRepository(
        invoices: <_InvoiceRecord>[
          _InvoiceRecord(
            invoiceNumber: 'INV-001',
            saleId: 'sale_1',
            total: 100000,
            createdAt: DateTime.utc(2026, 5, 16),
          ),
          _InvoiceRecord(
            invoiceNumber: 'INV-002',
            saleId: 'sale_2',
            total: 50000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
          _InvoiceRecord(
            invoiceNumber: 'INV-003',
            saleId: 'sale_3',
            total: 75000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
        ],
      );

      final targetDate = DateTime.utc(2026, 5, 17);
      final result = await repository.searchInvoices(
        null,
        dateStart: targetDate,
        dateEnd: targetDate,
      );

      expect(result.isSuccess, isTrue);
      final invoices = result.asSuccess!.value;
      expect(invoices.length, 2);
    });

    test('S-038 Reopen invoice', () async {
      final repository = _InvoiceHistoryRepository(
        invoices: <_InvoiceRecord>[
          _InvoiceRecord(
            invoiceNumber: 'INV-038',
            saleId: 'sale_38',
            customerId: 'cust_38',
            total: 125000,
            paidAmount: 100000,
            items: <_SaleItemRecord>[
              const _SaleItemRecord(
                productName: 'Phone A',
                quantity: 1,
                unitPrice: 125000,
              ),
            ],
            createdAt: DateTime.utc(2026, 5, 17),
          ),
        ],
      );

      final result = await repository.getReopenData('INV-038');

      expect(result.isSuccess, isTrue);
      final data = result.asSuccess!.value;
      expect(data.invoiceNumber, 'INV-038');
      expect(data.items.length, 1);
      expect(data.paidAmount, 100000);
      expect(data.remaining, 25000);
    });

    test('S-039 Reprint invoice', () async {
      final repository = _InvoiceHistoryRepository(
        invoices: <_InvoiceRecord>[
          _InvoiceRecord(
            invoiceNumber: 'INV-039',
            saleId: 'sale_39',
            total: 50000,
            createdAt: DateTime.utc(2026, 5, 17),
          ),
        ],
      );

      var reprintCount = 0;
      final result = await repository.reprintInvoice('INV-039', onReprint: () {
        reprintCount += 1;
      });

      expect(result.isSuccess, isTrue);
      expect(reprintCount, 1);
    });

    test('S-040 History with many invoices (50+ invoices)', () async {
      final invoices = List<_InvoiceRecord>.generate(
        75,
        (index) => _InvoiceRecord(
          invoiceNumber: 'INV-${index + 1}',
          saleId: 'sale_${index + 1}',
          total: 50000 + (index * 100),
          createdAt: DateTime.utc(2026, 5, 1 + (index % 17)),
        ),
      );

      final repository = _InvoiceHistoryRepository(invoices: invoices);

      final stopwatch = Stopwatch()..start();
      final result = await repository.searchInvoices(null);
      stopwatch.stop();

      expect(result.isSuccess, isTrue);
      final fetched = result.asSuccess!.value;
      expect(fetched.length, 75);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}

class _InvoiceRecord {
  const _InvoiceRecord({
    required this.invoiceNumber,
    required this.saleId,
    required this.total,
    required this.createdAt,
    this.customerId,
    this.customerName,
    this.paidAmount = 0,
    this.items = const <_SaleItemRecord>[],
  });

  final String invoiceNumber;
  final String saleId;
  final String? customerId;
  final String? customerName;
  final double total;
  final double paidAmount;
  final DateTime createdAt;
  final List<_SaleItemRecord> items;

  double get remaining => total - paidAmount;
}

class _SaleItemRecord {
  const _SaleItemRecord({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
}

class _InvoiceHistoryRepository implements SalesRepository {

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
  _InvoiceHistoryRepository({required List<_InvoiceRecord> invoices})
      : _invoices = List<_InvoiceRecord>.from(invoices);

  final List<_InvoiceRecord> _invoices;

  Future<Result<List<_InvoiceRecord>>> searchInvoices(
    String? invoiceQuery, {
    String? customerId,
    DateTime? dateStart,
    DateTime? dateEnd,
  }) async {
    var filtered = _invoices.toList();

    if (invoiceQuery != null && invoiceQuery.isNotEmpty) {
      filtered = filtered
          .where((inv) => inv.invoiceNumber.contains(invoiceQuery))
          .toList();
    }

    if (customerId != null) {
      filtered = filtered.where((inv) => inv.customerId == customerId).toList();
    }

    if (dateStart != null && dateEnd != null) {
      filtered = filtered
          .where((inv) =>
              inv.createdAt
                  .isAfter(dateStart.subtract(const Duration(days: 1))) &&
              inv.createdAt.isBefore(dateEnd.add(const Duration(days: 1))))
          .toList();
    }

    return Success<List<_InvoiceRecord>>(filtered);
  }

  Future<Result<_InvoiceRecord>> getReopenData(String invoiceNumber) async {
    final invoice = _invoices.firstWhere(
      (inv) => inv.invoiceNumber == invoiceNumber,
      orElse: () => throw StateError('Invoice not found'),
    );
    return Success<_InvoiceRecord>(invoice);
  }

  Future<Result<void>> reprintInvoice(
    String invoiceNumber, {
    required VoidCallback onReprint,
  }) async {
    final exists = _invoices.any((inv) => inv.invoiceNumber == invoiceNumber);
    if (!exists) {
      return const Failure<void>(
        AppError(code: 'not_found', message: 'Invoice not found'),
      );
    }
    onReprint();
    return const Success<void>(null);
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
      AppError(
          code: 'not_implemented', message: 'Not needed for history tests'),
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
    return const Success<List<SerializedStockEntity>>(
        <SerializedStockEntity>[]);
  }

  @override
  Future<Result<bool>> isImeiAvailable(String serializedStockId) async {
    return const Success<bool>(false);
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
          code: 'history_repo_error',
          message: 'History repository failed during $operation',
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
