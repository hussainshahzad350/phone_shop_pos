import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/repairing/data/repositories/sqlite_repairing_repository.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/repositories/repairing_repository.dart';

final repairingRepositoryProvider =
    FutureProvider<RepairingRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteRepairingRepository(appDatabase: appDatabase);
});

final repairJobsSearchQueryProvider = StateProvider<String>((ref) => '');
final repairJobsStatusFilterProvider = StateProvider<String>((ref) => '');
final repairJobsStartDateProvider = StateProvider<DateTime?>((ref) => null);
final repairJobsEndDateProvider = StateProvider<DateTime?>((ref) => null);
final repairJobsIncludeArchivedProvider = StateProvider<bool>((ref) => false);

final repairJobsProvider = FutureProvider<List<RepairJobEntity>>((ref) async {
  final repository = await ref.watch(repairingRepositoryProvider.future);
  final result = await repository.getRepairJobs(
    searchQuery: ref.watch(repairJobsSearchQueryProvider),
    status: ref.watch(repairJobsStatusFilterProvider),
    startDate: ref.watch(repairJobsStartDateProvider),
    endDate: ref.watch(repairJobsEndDateProvider),
    includeArchived: ref.watch(repairJobsIncludeArchivedProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final repairKpisProvider = FutureProvider<RepairKpiEntity>((ref) async {
  final repository = await ref.watch(repairingRepositoryProvider.future);
  final result = await repository.getRepairKpis();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});

final repairAnalyticsStartDateProvider =
    StateProvider<DateTime?>((ref) => null);
final repairAnalyticsEndDateProvider = StateProvider<DateTime?>((ref) => null);

final repairAnalyticsProvider =
    FutureProvider<RepairAnalyticsEntity>((ref) async {
  final repository = await ref.watch(repairingRepositoryProvider.future);
  final result = await repository.getRepairAnalytics(
    startDate: ref.watch(repairAnalyticsStartDateProvider),
    endDate: ref.watch(repairAnalyticsEndDateProvider),
  );
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw error,
  );
});
