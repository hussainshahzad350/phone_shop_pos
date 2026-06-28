import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_completion_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';

abstract class PurchaseRepository extends BaseRepository {
  Future<Result<List<SupplierOptionEntity>>> searchSuppliers(
    String query, {
    int limit = 20,
  });

  Future<Result<List<ProductEntity>>> searchProducts(
    String query, {
    int limit = 20,
  });

  Future<Result<bool>> isImeiUnique(String imei);

  /// Returns the next systematic purchase invoice number that would be
  /// generated for today (e.g. `PUR-YYYYMMDD-0001`) without reserving it.
  /// Used to preview the number in the form before saving.
  Future<Result<String>> peekNextInvoiceNumber();

  Future<Result<PurchaseCompletionEntity>> createPurchaseTransaction({
    required List<PurchaseFormItem> items,
    required double discount,
    required double tax,
    required double paidAmount,
    String? paymentMethod,
    String? supplierId,
    String? invoiceNumber,
    String? notes,
  });

  Future<Result<PurchaseEntity>> getPurchaseById(String purchaseId);

  Future<Result<void>> voidPurchase({
    required String purchaseId,
    required String voidReason,
    String? voidedBy,
  });
}
