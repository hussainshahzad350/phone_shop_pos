import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:phone_shop_pos/core/services/cloud/supabase_storage_client.dart';

String? _header(http.BaseRequest request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

SupabaseStorageClient _client(http.Client mock) {
  return SupabaseStorageClient(
    baseUrl: 'https://demo.supabase.co',
    publishableKey: 'pk',
    bucket: 'shop-backups',
    client: mock,
  );
}

void main() {
  group('SupabaseStorageClient', () {
    test('upload posts bytes to the object path and succeeds on 2xx', () async {
      http.Request? captured;
      final client = _client(MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      }));

      final result = await client.upload(
        path: 'user-1/backup.db.gz',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        accessToken: 'token-xyz',
      );

      expect(result.isSuccess, isTrue);
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(
        captured!.url.toString(),
        'https://demo.supabase.co/storage/v1/object/shop-backups/user-1/backup.db.gz',
      );
      expect(_header(captured!, 'Authorization'), 'Bearer token-xyz');
      expect(_header(captured!, 'x-upsert'), 'true');
      expect(captured!.bodyBytes, <int>[1, 2, 3]);
    });

    test('upload reports failure on a non-2xx response', () async {
      final client = _client(MockClient((request) async {
        return http.Response('{"message":"denied"}', 403);
      }));

      final result = await client.upload(
        path: 'user-1/backup.db.gz',
        bytes: Uint8List(0),
        accessToken: 'token',
      );

      expect(result.isFailure, isTrue);
    });

    test('list parses files and skips pseudo-folders', () async {
      final body = jsonEncode(<Object?>[
        <String, Object?>{
          'name': 'backup_1.db.gz',
          'created_at': '2026-06-26T00:00:00.000Z',
          'metadata': <String, Object?>{'size': 2048},
        },
        <String, Object?>{'name': 'nested-folder'},
      ]);
      final client = _client(MockClient((request) async {
        return http.Response(body, 200);
      }));

      final result = await client.list(prefix: 'user-1/', accessToken: 'token');

      expect(result.isSuccess, isTrue);
      final objects = result.asSuccess!.value;
      expect(objects.length, 1);
      expect(objects.first.name, 'backup_1.db.gz');
      expect(objects.first.sizeBytes, 2048);
    });

    test('download returns the response bytes', () async {
      final client = _client(MockClient((request) async {
        return http.Response.bytes(<int>[9, 8, 7], 200);
      }));

      final result = await client.download(
        path: 'user-1/backup.db.gz',
        accessToken: 'token',
      );

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess!.value, equals(Uint8List.fromList(<int>[9, 8, 7])));
    });
  });
}
