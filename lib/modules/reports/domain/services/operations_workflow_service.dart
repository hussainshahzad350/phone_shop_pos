import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/settlement_request_payload.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/operations_history_query_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/ledger_facade_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/stock_adjustment_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/credit_collection_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/supplier_payment_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/sale_return_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/purchase_return_service.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/cash_flow_service.dart';

class OperationsWorkflowService with BaseRepositoryGuard {
  OperationsWorkflowService({
    required AppDatabase appDatabase,
    LedgerPostingService? ledgerPostingService,
  })  : _historyQueryService = OperationsHistoryQueryService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _ledgerFacadeService = LedgerFacadeService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _stockAdjustmentService = StockAdjustmentService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _creditCollectionService = CreditCollectionService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _supplierPaymentService = SupplierPaymentService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _saleReturnService = SaleReturnService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _purchaseReturnService = PurchaseReturnService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        ),
        _cashFlowService = CashFlowService(
          appDatabase: appDatabase,
          ledgerPostingService: ledgerPostingService,
        );

  final OperationsHistoryQueryService _historyQueryService;
  final LedgerFacadeService _ledgerFacadeService;
  final StockAdjustmentService _stockAdjustmentService;
  final CreditCollectionService _creditCollectionService;
  final SupplierPaymentService _supplierPaymentService;
  final SaleReturnService _saleReturnService;
  final PurchaseReturnService _purchaseReturnService;
  final CashFlowService _cashFlowService;

  Future<Result<List<SalesHistoryRowEntity>>> searchSalesHistory({
    required String invoiceQuery,
    required String customerQuery,
    required DateTime? startDate,
    required DateTime? endDate,
    bool pendingOnly = false,
    bool collectibleOnly = false,
    int limit = 100,
    int offset = 0,
  }) {
    return _historyQueryService.searchSalesHistory(
      invoiceQuery: invoiceQuery,
      customerQuery: customerQuery,
      startDate: startDate,
      endDate: endDate,
      pendingOnly: pendingOnly,
      collectibleOnly: collectibleOnly,
      limit: limit,
      offset: offset,
    );
  }

  Future<Result<SalesInvoiceDetailEntity?>> getSalesInvoiceDetail(
    String saleId,
  ) {
    return _historyQueryService.getSalesInvoiceDetail(saleId);
  }

  Future<Result<PaymentCollectionEntity>> collectPayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) {
    return _creditCollectionService.collectPayment(
      saleId: saleId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  Future<Result<void>> processReturn({
    required String saleId,
    required SalesInvoiceItemEntity item,
    required int quantity,
    required String reason,
    String? notes,
  }) {
    return _saleReturnService.processReturn(
      saleId: saleId,
      item: item,
      quantity: quantity,
      reason: reason,
      notes: notes,
    );
  }

  Future<Result<void>> processPurchaseReturn({
    required String purchaseId,
    required PurchaseHistoryItemEntity item,
    required int quantity,
    required String reason,
    String? notes,
  }) {
    return _purchaseReturnService.processPurchaseReturn(
      purchaseId: purchaseId,
      item: item,
      quantity: quantity,
      reason: reason,
      notes: notes,
    );
  }

  Future<Result<List<PurchaseHistoryRowEntity>>> searchPurchaseHistory({
    required String supplierQuery,
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) {
    return _historyQueryService.searchPurchaseHistory(
      supplierQuery: supplierQuery,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  Future<Result<PurchaseHistoryDetailEntity?>> getPurchaseHistoryDetail(
    String purchaseId,
  ) {
    return _historyQueryService.getPurchaseHistoryDetail(purchaseId);
  }

  Future<Result<List<SupplierLedgerRowEntity>>> getSupplierLedger({
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 200,
    int offset = 0,
  }) {
    return _ledgerFacadeService.getSupplierLedger(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  Future<Result<List<LedgerTimelineRowEntity>>> fetchCustomerLedgerTimeline({
    String? customerId,
    String? ledgerType,
    DateTime? startDate,
    DateTime? endDate,
    bool outstandingOnly = false,
    bool includePaymentHistory = true,
  }) {
    return _ledgerFacadeService.fetchCustomerLedgerTimeline(
      customerId: customerId,
      ledgerType: ledgerType,
      startDate: startDate,
      endDate: endDate,
      outstandingOnly: outstandingOnly,
      includePaymentHistory: includePaymentHistory,
    );
  }

  Future<Result<List<LedgerTimelineRowEntity>>> fetchSupplierLedgerTimeline({
    String? supplierId,
    String? ledgerType,
    DateTime? startDate,
    DateTime? endDate,
    bool outstandingOnly = false,
    bool includePaymentHistory = true,
  }) {
    return _ledgerFacadeService.fetchSupplierLedgerTimeline(
      supplierId: supplierId,
      ledgerType: ledgerType,
      startDate: startDate,
      endDate: endDate,
      outstandingOnly: outstandingOnly,
      includePaymentHistory: includePaymentHistory,
    );
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchCustomerLedgerSummary({
    String? customerId,
    bool outstandingOnly = false,
  }) {
    return _ledgerFacadeService.fetchCustomerLedgerSummary(
      customerId: customerId,
      outstandingOnly: outstandingOnly,
    );
  }

  Future<Result<List<PartySummaryCardEntity>>> fetchSupplierLedgerSummary({
    String? supplierId,
    bool outstandingOnly = false,
  }) {
    return _ledgerFacadeService.fetchSupplierLedgerSummary(
      supplierId: supplierId,
      outstandingOnly: outstandingOnly,
    );
  }

  Future<Result<void>> receiveCustomerCredit(
    CustomerSettlementRequestPayload payload,
  ) {
    return _creditCollectionService.receiveCustomerCredit(payload);
  }

  Future<Result<void>> paySupplierCredit(
    SupplierSettlementRequestPayload payload,
  ) {
    return _supplierPaymentService.paySupplierCredit(payload);
  }

  Future<Result<List<CashLedgerRowEntity>>> getCashLedger({
    required DateTime? startDate,
    required DateTime? endDate,
    int limit = 200,
    int offset = 0,
  }) {
    return _cashFlowService.getCashLedger(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  Future<Result<int>> applyQuantityStockAdjustment({
    required String productModelId,
    required int delta,
    required String reason,
    String? notes,
  }) {
    return _stockAdjustmentService.applyQuantityStockAdjustment(
      productModelId: productModelId,
      delta: delta,
      reason: reason,
      notes: notes,
    );
  }

  Future<Result<void>> writeOffSerializedStock({
    required String serializedStockId,
    required String reason,
    String? notes,
  }) {
    return _stockAdjustmentService.writeOffSerializedStock(
      serializedStockId: serializedStockId,
      reason: reason,
      notes: notes,
    );
  }

  Future<Result<List<StockAdjustmentHistoryRowEntity>>> getStockAdjustments({
    int limit = 200,
    int offset = 0,
  }) {
    return _historyQueryService.getStockAdjustments(
      limit: limit,
      offset: offset,
    );
  }
}
