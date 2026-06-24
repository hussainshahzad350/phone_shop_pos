import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/config/business_configuration.dart';
import 'package:phone_shop_pos/core/config/business_configuration_repository.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';

final businessConfigurationDefaultsProvider =
    Provider<BusinessConfiguration>((ref) {
  return BusinessConfiguration.defaults();
});

final businessConfigurationRepositoryProvider =
    FutureProvider<BusinessConfigurationRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return BusinessConfigurationRepository(appDatabase: appDatabase);
});

final businessConfigurationProvider =
    FutureProvider<BusinessConfiguration>((ref) async {
  final defaults = ref.watch(businessConfigurationDefaultsProvider);
  final repository =
      await ref.watch(businessConfigurationRepositoryProvider.future);
  return repository.load(defaults);
});

final businessProfileProvider = FutureProvider<BusinessProfile>((ref) async {
  final configuration = await ref.watch(businessConfigurationProvider.future);
  return configuration.profile;
});
