import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_imei_management_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/imei_management_entry.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/imei_management_repository.dart';

final imeiManagementRepositoryProvider =
    FutureProvider<ImeiManagementRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteImeiManagementRepository(appDatabase: appDatabase);
});

/// Loads all IMEIs for a given [productModelId]. Invalidated after mutations.
final imeiListForModelProvider = FutureProvider.family<
    List<ImeiManagementEntry>, String>((ref, productModelId) async {
  final repo = await ref.watch(imeiManagementRepositoryProvider.future);
  final result = await repo.getImeisForModel(productModelId);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (e) => throw e,
  );
});
