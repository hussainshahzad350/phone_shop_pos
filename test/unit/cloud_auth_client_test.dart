import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phone_shop_pos/core/services/cloud/cloud_auth_client.dart';

SupabaseAuthClient _client(http.Client mock) {
  return SupabaseAuthClient(
    baseUrl: 'https://demo.supabase.co',
    publishableKey: 'pk',
    client: mock,
    now: () => DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('SupabaseAuthClient', () {
    test('verify parses a token response into a session', () async {
      final body = jsonEncode(<String, Object?>{
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 3600,
        'user': <String, Object?>{'id': 'user-1', 'email': 'owner@shop.com'},
      });
      http.Request? captured;
      final client = _client(MockClient((request) async {
        captured = request;
        return http.Response(body, 200);
      }));

      final result = await client.verify(email: 'owner@shop.com', token: '123456');

      expect(result.isSuccess, isTrue);
      final session = result.asSuccess!.value;
      expect(session.accessToken, 'access');
      expect(session.userId, 'user-1');
      expect(session.expiresAt, DateTime.utc(2026, 1, 1, 1));
      expect(captured!.url.path, '/auth/v1/verify');
    });

    test('verify fails on a non-2xx response', () async {
      final client = _client(MockClient((request) async {
        return http.Response('{"msg":"invalid"}', 401);
      }));

      final result = await client.verify(email: 'a@b.com', token: '000000');

      expect(result.isFailure, isTrue);
    });

    test('refresh hits the token endpoint with the refresh grant', () async {
      final body = jsonEncode(<String, Object?>{
        'access_token': 'fresh',
        'refresh_token': 'refresh2',
        'expires_in': 3600,
        'user': <String, Object?>{'id': 'user-1'},
      });
      http.Request? captured;
      final client = _client(MockClient((request) async {
        captured = request;
        return http.Response(body, 200);
      }));

      final result = await client.refresh('old-refresh');

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess!.value.accessToken, 'fresh');
      expect(captured!.url.path, '/auth/v1/token');
      expect(captured!.url.queryParameters['grant_type'], 'refresh_token');
    });
  });
}
