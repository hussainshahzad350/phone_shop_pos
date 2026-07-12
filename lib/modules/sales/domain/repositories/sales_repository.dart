import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/imei_trace_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_completion_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_header_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

abstract class SalesRepository extends BaseRepository {
  Future<Result<List<ProductEntity>>> searchSellableProducts(
    String query, {
    int limit = 20,
  });

  Future<Result<List<CustomerOptionEntity>>> searchCustomers(
    String query, {
    int limit = 20,
  });

  Future<Result<List<SerializedStockEntity>>> getAvailableImeis(
    String productModelId, {
    String query = '',
    int limit = 20,
  });

  Future<Result<int>> getAvailableQuantity(String productModelId);

  Future<Result<bool>> isImeiAvailable(String serializedStockId);

  /// Creates a sale transaction.  The invoice number is generated atomically
  /// inside the transaction using the DB-backed sequence table to prevent
  /// collisions under rapid consecutive saves.
  Future<Result<SaleCompletionEntity>> createSaleTransaction({
    required List<CartItemEntity> items,
    required SaleTotalsEntity totals,
    required DateTime saleDate,
    String? customerId,
    String? userId,
    String? paymentMethod,
    String? notes,
  });

  Future<Result<SaleHeaderEntity>> getSaleById(String saleId);

  Future<Result<void>> voidSale({
    required String saleId,
    required String voidReason,
    String? voidedBy,
  });

  /// Returns a map of supplierId → supplierName for the given IDs.
  /// Unknown or null IDs are omitted from the result.
  Future<Result<Map<String, String>>> getSupplierNames(List<String> supplierIds);

  /// Looks up the full purchase + sale history for a single IMEI.
  /// Returns null when no matching IMEI is found.
  Future<Result<ImeiTraceEntity?>> getImeiTrace(String imei);
}
