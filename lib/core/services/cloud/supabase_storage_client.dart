import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/cloud/cloud_storage_client.dart';

/// [CloudStorageClient] backed by Supabase Storage's REST API. Each request is
/// authorized with the shop's user access token (so per-account access rules
/// apply) plus the public anon/publishable key as the `apikey`.
class SupabaseStorageClient implements CloudStorageClient {
  SupabaseStorageClient({
    required this.baseUrl,
    required this.publishableKey,
    required this.bucket,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String publishableKey;
  final String bucket;
  final http.Client _client;

  Map<String, String> _headers(String accessToken) => <String, String>{
        'apikey': publishableKey,
        'Authorization': 'Bearer $accessToken',
      };

  @override
  Future<Result<void>> upload({
    required String path,
    required Uint8List bytes,
    required String accessToken,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/storage/v1/object/$bucket/$path'),
        headers: <String, String>{
          ..._headers(accessToken),
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
        body: bytes,
      );
      if (_isSuccess(response.statusCode)) {
        return const Success<void>(null);
      }
      return Failure<void>(_error('cloud_upload_failed', response));
    } catch (error) {
      return Failure<void>(_networkError(error));
    }
  }

  @override
  Future<Result<List<CloudStorageObject>>> list({
    required String prefix,
    required String accessToken,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/storage/v1/object/list/$bucket'),
        headers: <String, String>{
          ..._headers(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object?>{
          'prefix': prefix,
          'limit': 100,
          'sortBy': <String, Object?>{
            'column': 'created_at',
            'order': 'desc',
          },
        }),
      );
      if (!_isSuccess(response.statusCode)) {
        return Failure<List<CloudStorageObject>>(
          _error('cloud_list_failed', response),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const Success<List<CloudStorageObject>>(<CloudStorageObject>[]);
      }
      final objects = <CloudStorageObject>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final name = item['name'] as String?;
        if (name == null) {
          continue;
        }
        final metadata = item['metadata'];
        // Entries without metadata are pseudo-folders, not files.
        if (metadata is! Map) {
          continue;
        }
        objects.add(
          CloudStorageObject(
            name: name,
            sizeBytes: (metadata['size'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.tryParse(item['created_at'] as String? ?? ''),
          ),
        );
      }
      return Success<List<CloudStorageObject>>(objects);
    } catch (error) {
      return Failure<List<CloudStorageObject>>(_networkError(error));
    }
  }

  @override
  Future<Result<Uint8List>> download({
    required String path,
    required String accessToken,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/storage/v1/object/$bucket/$path'),
        headers: _headers(accessToken),
      );
      if (_isSuccess(response.statusCode)) {
        return Success<Uint8List>(response.bodyBytes);
      }
      return Failure<Uint8List>(_error('cloud_download_failed', response));
    } catch (error) {
      return Failure<Uint8List>(_networkError(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String path,
    required String accessToken,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/storage/v1/object/$bucket/$path'),
        headers: _headers(accessToken),
      );
      if (_isSuccess(response.statusCode)) {
        return const Success<void>(null);
      }
      return Failure<void>(_error('cloud_delete_failed', response));
    } catch (error) {
      return Failure<void>(_networkError(error));
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  AppError _error(String code, http.Response response) {
    return AppError(
      code: code,
      message: 'Cloud storage request failed (HTTP ${response.statusCode}).',
      details: response.body,
    );
  }

  AppError _networkError(Object error) {
    return AppError(
      code: 'cloud_network_error',
      message: 'No internet connection or the cloud service is unreachable.',
      details: error,
    );
  }
}
