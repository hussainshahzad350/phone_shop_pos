import 'dart:convert';

/// A persisted Supabase auth session for the signed-in shop account, used to
/// authorize cloud backup uploads/downloads. Stored locally so the device stays
/// signed in across restarts (the refresh token mints new access tokens).
class SupabaseSession {
  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
    this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;
  final String? email;

  /// True when the access token is expired or within a small safety window of
  /// expiring, so callers know to refresh before using it.
  bool isExpired({DateTime? now, Duration leeway = const Duration(minutes: 2)}) {
    final reference = (now ?? DateTime.now().toUtc()).add(leeway);
    return !reference.isBefore(expiresAt);
  }

  SupabaseSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? userId,
    DateTime? expiresAt,
    String? email,
  }) {
    return SupabaseSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      expiresAt: expiresAt ?? this.expiresAt,
      email: email ?? this.email,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'email': email,
    };
  }

  String encode() => jsonEncode(toJson());

  static SupabaseSession? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final accessToken = decoded['accessToken'] as String?;
      final refreshToken = decoded['refreshToken'] as String?;
      final userId = decoded['userId'] as String?;
      final expiresAtRaw = decoded['expiresAt'] as String?;
      if (accessToken == null ||
          refreshToken == null ||
          userId == null ||
          expiresAtRaw == null) {
        return null;
      }
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt == null) {
        return null;
      }
      return SupabaseSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        expiresAt: expiresAt.toUtc(),
        email: decoded['email'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Builds a session from a Supabase GoTrue token response
  /// (`/auth/v1/verify` or refresh), returning null if required fields are
  /// missing.
  static SupabaseSession? fromTokenResponse(
    Map<String, Object?> body, {
    DateTime? now,
  }) {
    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      return null;
    }
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    final user = body['user'];
    final userId = user is Map<String, Object?> ? user['id'] as String? : null;
    final email = user is Map<String, Object?> ? user['email'] as String? : null;
    if (userId == null) {
      return null;
    }
    final issuedAt = now ?? DateTime.now().toUtc();
    return SupabaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: issuedAt.add(Duration(seconds: expiresIn)),
      email: email,
    );
  }
}
