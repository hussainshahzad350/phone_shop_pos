import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';

abstract class DealerIssueRepository {
  Future<Result<List<DealerIssueEntity>>> getAllIssues();
  Future<Result<DealerIssueEntity>> getIssueById(String issueId);
  Future<Result<List<DealerIssueEntity>>> getIssuesByDealer(String dealerId);
  Future<Result<List<DealerIssueEntity>>> getIssuesByStatus(String status);
  Future<Result<DealerIssueEntity>> createIssue(DealerIssueEntity issue);
  Future<Result<bool>> updateIssue(DealerIssueEntity issue);
  Future<Result<bool>> deleteIssue(String issueId);
  Future<Result<bool>> markAsReturned(String issueId);
  Future<Result<bool>> convertToSale(String issueId, String saleInvoiceId);
  Future<Result<bool>> markAsSold(String issueId);
  Future<Result<String>> markAsSoldViaDealer({
    required String issueId,
    required double salePrice,
    required String paymentMethod,
  });
  Future<Result<List<String>>> getAvailableImeisForIssue(String dealerId);
  Future<Result<bool>> isImeiUniqueForDealer(String imei, String dealerId, {String? excludeIssueId});
}