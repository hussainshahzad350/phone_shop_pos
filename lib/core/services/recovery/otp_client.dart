/// Result of an email OTP operation (sending or verifying a code).
class OtpOutcome {
  const OtpOutcome._(this.success, this.errorMessage);

  const OtpOutcome.ok() : this._(true, null);

  const OtpOutcome.failure(String message) : this._(false, message);

  final bool success;
  final String? errorMessage;
}

/// Transport-agnostic email one-time-password client.
///
/// Implemented over Supabase's GoTrue REST API in production and faked in
/// tests, so the recovery flow can be exercised without a network.
abstract class OtpClient {
  /// Emails a one-time code to [email].
  Future<OtpOutcome> sendCode(String email);

  /// Verifies the [token] the user received at [email].
  Future<OtpOutcome> verifyCode({
    required String email,
    required String token,
  });
}
