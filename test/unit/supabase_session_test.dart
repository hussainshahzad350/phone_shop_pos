import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';

void main() {
  group('SupabaseSession', () {
    final session = SupabaseSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'user-1',
      expiresAt: DateTime.utc(2026, 6, 26, 1),
      email: 'owner@shop.com',
    );

    test('encode/tryParse round-trips', () {
      final parsed = SupabaseSession.tryParse(session.encode());

      expect(parsed, isNotNull);
      expect(parsed!.accessToken, 'access');
      expect(parsed.refreshToken, 'refresh');
      expect(parsed.userId, 'user-1');
      expect(parsed.expiresAt, session.expiresAt);
      expect(parsed.email, 'owner@shop.com');
    });

    test('tryParse returns null for malformed input', () {
      expect(SupabaseSession.tryParse(null), isNull);
      expect(SupabaseSession.tryParse(''), isNull);
      expect(SupabaseSession.tryParse('not json'), isNull);
      expect(SupabaseSession.tryParse('{"accessToken":"a"}'), isNull);
    });

    test('fromTokenResponse builds a session with a computed expiry', () {
      final issuedAt = DateTime.utc(2026, 1, 1);
      final built = SupabaseSession.fromTokenResponse(
        <String, Object?>{
          'access_token': 'a',
          'refresh_token': 'r',
          'expires_in': 3600,
          'user': <String, Object?>{'id': 'u', 'email': 'e@x.com'},
        },
        now: issuedAt,
      );

      expect(built, isNotNull);
      expect(built!.userId, 'u');
      expect(built.email, 'e@x.com');
      expect(built.expiresAt, issuedAt.add(const Duration(seconds: 3600)));
    });

    test('fromTokenResponse returns null without tokens or user id', () {
      expect(
        SupabaseSession.fromTokenResponse(<String, Object?>{'user': <String, Object?>{'id': 'u'}}),
        isNull,
      );
      expect(
        SupabaseSession.fromTokenResponse(<String, Object?>{
          'access_token': 'a',
          'refresh_token': 'r',
        }),
        isNull,
      );
    });

    test('isExpired respects the leeway window', () {
      expect(session.isExpired(now: DateTime.utc(2026, 6, 26, 2)), isTrue);
      expect(session.isExpired(now: DateTime.utc(2026, 6, 26)), isFalse);
      // Within the 2-minute leeway of the 01:00 expiry -> treated as expired.
      expect(
        session.isExpired(now: DateTime.utc(2026, 6, 26, 0, 59)),
        isTrue,
      );
    });
  });
}
