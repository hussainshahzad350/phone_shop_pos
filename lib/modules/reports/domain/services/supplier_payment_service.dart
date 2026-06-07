import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';

class SupplierPaymentService with BaseRepositoryGuard {
  SupplierPaymentService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  }) : _ledgerPostingService = ledgerPostingService;

  final LedgerPostingService? _ledgerPostingService;

  Future<Result<void>> paySupplierCredit(
    SupplierSettlementRequestPayload payload,
  ) {
    if (_ledgerPostingService == null) {
      return guard<void>(() async {
        throw StateError('Ledger posting service is unavailable.');
      });
    }
    return _ledgerPostingService.paySupplierCredit(payload);
  }
}
