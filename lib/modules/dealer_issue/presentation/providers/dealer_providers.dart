import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/data/repositories/sqlite_dealer_repository.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/repositories/dealer_repository.dart';

final dealerRepositoryProvider = Provider<DealerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).value!;
  return SqliteDealerRepository(appDatabase: db);
});

final dealerListProvider = FutureProvider<List<DealerEntity>>((ref) async {
  final repo = ref.watch(dealerRepositoryProvider);
  final result = await repo.getAllDealers();
  return result.fold(onSuccess: (v) => v, onFailure: (_) => const []);
});
