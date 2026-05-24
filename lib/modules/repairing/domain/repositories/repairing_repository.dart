import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';

abstract class RepairingRepository {
  Future<Result<List<RepairJobEntity>>> getRepairJobs({
    String? searchQuery,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool includeArchived = false,
  });

  Future<Result<RepairJobEntity?>> getRepairJobById(String id);

  Future<Result<void>> addRepairJob(RepairJobEntity job);

  Future<Result<void>> updateRepairJob(RepairJobEntity job);

  Future<Result<void>> collectPayment(
    String id,
    double amount, {
    String? notes,
  });

  Future<Result<void>> updateStatus(String id, String status);

  Future<Result<void>> deleteRepairJob(String id);

  Future<Result<void>> restoreRepairJob(String id);

  Future<Result<RepairKpiEntity>> getRepairKpis();

  Future<Result<RepairAnalyticsEntity>> getRepairAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  });
}
