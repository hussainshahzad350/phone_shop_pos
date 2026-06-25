import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/config/shop_profile.dart';
import 'package:phone_shop_pos/core/config/shop_profile_repository.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';

final shopProfileRepositoryProvider =
    FutureProvider<ShopProfileRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return ShopProfileRepository(appDatabase: appDatabase);
});

/// Holds the current shop letterhead. Starts from sensible defaults and is
/// hydrated from the database once it is available, so callers (e.g. the
/// receipt renderer) always have a synchronous, non-null value to read.
class ShopProfileNotifier extends StateNotifier<ShopProfile> {
  ShopProfileNotifier(this._ref) : super(ShopProfile.unconfigured()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final repository = await _ref.read(shopProfileRepositoryProvider.future);
      state = await repository.load(ShopProfile.unconfigured());
    } catch (_) {
      // Keep defaults if the database is not ready or load fails; the owner can
      // still configure and save, which will persist correctly.
    }
  }

  /// Persists [profile] and immediately reflects it so the next receipt render
  /// uses the new values.
  Future<void> save(ShopProfile profile) async {
    final repository = await _ref.read(shopProfileRepositoryProvider.future);
    await repository.save(profile);
    state = profile;
  }
}

final shopProfileProvider =
    StateNotifierProvider<ShopProfileNotifier, ShopProfile>(
  (ref) => ShopProfileNotifier(ref),
);
