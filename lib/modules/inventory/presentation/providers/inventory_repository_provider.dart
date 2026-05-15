import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_brand_repository.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/brand_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/inventory_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/repositories/product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/services/inventory_service.dart';

final brandRepositoryProvider = FutureProvider<BrandRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteBrandRepository(appDatabase: appDatabase);
});

final productRepositoryProvider =
    FutureProvider<ProductRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteProductRepository(appDatabase: appDatabase);
});

final inventoryRepositoryProvider =
    FutureProvider<InventoryRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SqliteInventoryRepository(appDatabase: appDatabase);
});

final inventoryServiceProvider = FutureProvider<InventoryService>((ref) async {
  final repository = await ref.watch(inventoryRepositoryProvider.future);
  return InventoryService(repository: repository);
});
