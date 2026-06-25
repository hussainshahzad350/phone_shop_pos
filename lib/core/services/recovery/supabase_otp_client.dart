import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:phone_shop_pos/core/services/recovery/otp_client.dart';

/// [OtpClient] backed by Supabase's GoTrue REST API.
///
/// Uses two plain HTTPS calls (no SDK), which keeps it usable on Windows
/// desktop where the full Supabase Flutter SDK pulls in unneeded plugins.
class SupabaseOtpClient implements OtpClient {
  SupabaseOtpClient({
    required this.baseUrl,
    required this.publishableKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String publishableKey;
  final http.Client _client;

  Map<String, String> get _headers => <String, String>{
        'apikey': publishableKey,
        'Authorization': 'Bearer $publishableKey',
        'Content-Type': 'application/json',
      };

  @override
  Future<OtpOutcome> sendCode(String email) async {
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
        return const OtpOutcome.ok();
      }
      return OtpOutcome.failure(
        _extractError(response.body) ??
            'Could not send the code. Please try again.',
      );
    } catch (_) {
      return const OtpOutcome.failure(
        'No internet connection. Connect to the internet and try again.',
      );
    }
  }

  @override
  Future<OtpOutcome> verifyCode({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/v1/verify'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{
          'type': 'email',
          'email': email,
          'token': token,
        }),
      );
      if (_isSuccess(response.statusCode)) {
        return const OtpOutcome.ok();
      }
      return OtpOutcome.failure(
        _extractError(response.body) ??
            'The code is incorrect or has expired.',
      );
    } catch (_) {
      return const OtpOutcome.failure(
        'No internet connection. Connect to the internet and try again.',
      );
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  String? _extractError(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final message = decoded['msg'] ??
            decoded['error_description'] ??
            decoded['error'] ??
            decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Non-JSON body; fall through to null so the caller uses a default.
    }
    return null;
  }
}
