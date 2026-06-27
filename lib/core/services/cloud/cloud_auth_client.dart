import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/cloud/supabase_session.dart';

/// Auth calls needed to sign a shop into its cloud-backup account: email OTP
/// send/verify and refresh-token exchange. Verify and refresh return a full
/// [SupabaseSession] (unlike the recovery OTP client, which only needs a
/// success flag).
abstract class CloudAuthClient {
  Future<Result<void>> sendCode(String email);

  Future<Result<SupabaseSession>> verify({
    required String email,
    required String token,
  });

  Future<Result<SupabaseSession>> refresh(String refreshToken);
}

class SupabaseAuthClient implements CloudAuthClient {
  SupabaseAuthClient({
    required this.baseUrl,
    required this.publishableKey,
    http.Client? client,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _now = now ?? (() => DateTime.now().toUtc());

  final String baseUrl;
  final String publishableKey;
  final http.Client _client;
  final DateTime Function() _now;

  Map<String, String> get _headers => <String, String>{
        'apikey': publishableKey,
        'Authorization': 'Bearer $publishableKey',
        'Content-Type': 'application/json',
      };

  @override
  Future<Result<void>> sendCode(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/v1/otp'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{
          'email': email,
          'create_user': true,
        }),
      );
      if (_isSuccess(response.statusCode)) {
        return const Success<void>(null);
      }
      return Failure<void>(_error('cloud_send_code_failed', response));
    } catch (error) {
      return Failure<void>(_networkError(error));
    }
  }

  @override
  Future<Result<SupabaseSession>> verify({
    required String email,
    required String token,
  }) async {
    return _sessionCall(
      uri: Uri.parse('$baseUrl/auth/v1/verify'),
      body: <String, Object?>{
        'type': 'email',
        'email': email,
        'token': token,
      },
      failureCode: 'cloud_verify_failed',
    );
  }

  @override
  Future<Result<SupabaseSession>> refresh(String refreshToken) async {
    return _sessionCall(
      uri: Uri.parse('$baseUrl/auth/v1/token?grant_type=refresh_token'),
      body: <String, Object?>{'refresh_token': refreshToken},
      failureCode: 'cloud_refresh_failed',
    );
  }

  Future<Result<SupabaseSession>> _sessionCall({
    required Uri uri,
    required Map<String, Object?> body,
    required String failureCode,
  }) async {
    try {
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      if (!_isSuccess(response.statusCode)) {
        return Failure<SupabaseSession>(_error(failureCode, response));
      }
      final decoded = jsonDecode(response.body);
      final session = decoded is Map<String, Object?>
          ? SupabaseSession.fromTokenResponse(decoded, now: _now())
          : null;
      if (session == null) {
        return Failure<SupabaseSession>(
          const AppError(
            code: 'cloud_session_parse_failed',
            message: 'The cloud sign-in response was not understood.',
          ),
        );
      }
      return Success<SupabaseSession>(session);
    } catch (error) {
      return Failure<SupabaseSession>(_networkError(error));
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  AppError _error(String code, http.Response response) {
    return AppError(
      code: code,
      message: 'Cloud sign-in request failed (HTTP ${response.statusCode}).',
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
