import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/imei_bulk_parser.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/bulk_imei_import_summary.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/imei_management_entry.dart';

abstract class ImeiManagementRepository extends BaseRepository {
  Future<Result<List<ImeiManagementEntry>>> getImeisForModel(
    String productModelId,
  );

  Future<Result<void>> addImei({
    required String productModelId,
    required String imei1,
    String? imei2,
    DateTime? purchaseDate,
    required double costPrice,
    String? supplierId,
  });

  /// Adds every valid, non-duplicate line from a bulk paste in one
  /// transaction. Invalid-format or already-in-stock lines are skipped and
  /// reported in the summary rather than aborting the whole batch.
  Future<Result<BulkImeiImportSummary>> addImeisBulk({
    required String productModelId,
    required List<ParsedImeiLine> entries,
    required DateTime purchaseDate,
    required double costPrice,
    String? supplierId,
  });

  /// Permanently deletes a serialized_stock row. Only allowed when status is
  /// in_stock (sold/reserved/damaged items are rejected to preserve history).
  Future<Result<void>> deleteImei(String stockId);

  Future<Result<void>> updatePurchaseInfo({
    required String stockId,
    DateTime? purchaseDate,
    required double costPrice,
    String? supplierId,
  });
}
