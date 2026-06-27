import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/config/supabase_config.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_client.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_backup_service.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_storage_client.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session_store.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_storage_client.dart';

final supabaseSessionStoreProvider =
    FutureProvider<SupabaseSessionStore>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return SupabaseSessionStore(appDatabase: appDatabase);
});

final cloudAuthClientProvider = Provider<CloudAuthClient>((ref) {
  return SupabaseAuthClient(
    baseUrl: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
});

final cloudStorageClientProvider = Provider<CloudStorageClient>((ref) {
  return SupabaseStorageClient(
    baseUrl: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    bucket: SupabaseConfig.backupsBucket,
  );
});

final cloudAuthServiceProvider = FutureProvider<CloudAuthService>((ref) async {
  final store = await ref.watch(supabaseSessionStoreProvider.future);
  return CloudAuthService(
    client: ref.watch(cloudAuthClientProvider),
    store: store,
  );
});

final cloudBackupServiceProvider =
    FutureProvider<CloudBackupService>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  final authService = await ref.watch(cloudAuthServiceProvider.future);
  return CloudBackupService(
    databaseBackupService: DatabaseBackupService(appDatabase: appDatabase),
    storageClient: ref.watch(cloudStorageClientProvider),
    authService: authService,
  );
});

/// Whether the device is currently signed into a cloud-backup account.
final cloudSignedInProvider = FutureProvider<bool>((ref) async {
  final authService = await ref.watch(cloudAuthServiceProvider.future);
  return authService.isSignedIn();
});

/// The signed-in account email, or null.
final cloudAccountEmailProvider = FutureProvider<String?>((ref) async {
  final authService = await ref.watch(cloudAuthServiceProvider.future);
  return authService.signedInEmail();
});
