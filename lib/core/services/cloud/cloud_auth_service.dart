import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_auth_client.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session_store.dart';

/// Manages the shop's cloud-backup account session: request a code, sign in
/// (which persists the session), keep a valid access token (refreshing when
/// expired), and sign out.
class CloudAuthService {
  CloudAuthService({
    required CloudAuthClient client,
    required SupabaseSessionStore store,
  })  : _client = client,
        _store = store;

  final CloudAuthClient _client;
  final SupabaseSessionStore _store;

  Future<Result<void>> requestCode(String email) {
    return _client.sendCode(email);
  }

  Future<Result<SupabaseSession>> signIn({
    required String email,
    required String token,
  }) async {
    final result = await _client.verify(email: email, token: token);
    if (result.isSuccess) {
      await _store.write(result.asSuccess!.value);
    }
    return result;
  }

  /// Returns a non-expired session, refreshing it if needed, or null if the
  /// device is not signed in or the refresh fails (e.g. offline or revoked).
  Future<SupabaseSession?> currentSession() async {
    final session = await _store.read();
    if (session == null) {
      return null;
    }
    if (!session.isExpired()) {
      return session;
    }
    final refreshed = await _client.refresh(session.refreshToken);
    if (refreshed.isSuccess) {
      final updated = refreshed.asSuccess!.value;
      await _store.write(updated);
      return updated;
    }
    return null;
  }

  Future<bool> isSignedIn() => _store.isSignedIn();

  Future<String?> signedInEmail() async => (await _store.read())?.email;

  Future<void> signOut() => _store.clear();
}
