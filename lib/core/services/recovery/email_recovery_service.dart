import 'package:phone_shop_pos/core/services/recovery/otp_client.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

/// Result of requesting a recovery code.
class RecoveryRequestResult {
  const RecoveryRequestResult._(this.status, {this.maskedEmail, this.error});

  const RecoveryRequestResult.sent(String maskedEmail)
      : this._(RecoveryRequestStatus.sent, maskedEmail: maskedEmail);

  const RecoveryRequestResult.noEmail()
      : this._(RecoveryRequestStatus.noEmail);

  const RecoveryRequestResult.failure(String error)
      : this._(RecoveryRequestStatus.failure, error: error);

  final RecoveryRequestStatus status;
  final String? maskedEmail;
  final String? error;
}

enum RecoveryRequestStatus { sent, noEmail, failure }

/// Result of verifying a code and resetting the PIN.
class RecoveryResetResult {
  const RecoveryResetResult._(this.status, {this.newRecoveryCode, this.error});

  const RecoveryResetResult.success(String newRecoveryCode)
      : this._(RecoveryResetStatus.success, newRecoveryCode: newRecoveryCode);

  const RecoveryResetResult.noEmail() : this._(RecoveryResetStatus.noEmail);

  const RecoveryResetResult.failure(String error)
      : this._(RecoveryResetStatus.failure, error: error);

  final RecoveryResetStatus status;
  final String? newRecoveryCode;
  final String? error;
}

enum RecoveryResetStatus { success, noEmail, failure }

/// Orchestrates "forgot PIN and recovery code" recovery via a one-time code
/// sent to the owner's registered email. The email is the unloseable recovery
/// authority; verifying it authorizes a local PIN reset (data is never
/// touched).
class EmailRecoveryService {
  EmailRecoveryService({
    required OtpClient otpClient,
    required LocalPinAuthService authService,
  })  : _otpClient = otpClient,
        _authService = authService;

  final OtpClient _otpClient;
  final LocalPinAuthService _authService;

  static final RegExp _pinPattern = RegExp(r'^\d{4,6}$');

  Future<RecoveryRequestResult> requestResetCode() async {
    final email = await _authService.getRecoveryEmail();
    if (email == null) {
      return const RecoveryRequestResult.noEmail();
    }
    final outcome = await _otpClient.sendCode(email);
    if (outcome.success) {
      return RecoveryRequestResult.sent(_maskEmail(email));
    }
    return RecoveryRequestResult.failure(
      outcome.errorMessage ?? 'Could not send the code.',
    );
  }

  Future<RecoveryResetResult> verifyAndResetPin({
    required String token,
    required String newPin,
  }) async {
    if (!_pinPattern.hasMatch(newPin)) {
      return const RecoveryResetResult.failure('PIN must be 4 to 6 digits.');
    }
    final email = await _authService.getRecoveryEmail();
    if (email == null) {
      return const RecoveryResetResult.noEmail();
    }
    final outcome = await _otpClient.verifyCode(
      email: email,
      token: token.trim(),
    );
    if (!outcome.success) {
      return RecoveryResetResult.failure(
        outcome.errorMessage ?? 'The code is incorrect or has expired.',
      );
    }
    final newRecoveryCode =
        await _authService.resetPinAfterEmailVerification(newPin);
    return RecoveryResetResult.success(newRecoveryCode);
  }

  /// Masks an address for display, e.g. `hussain@gmail.com` -> `hu•••@gmail.com`.
  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) {
      return email;
    }
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final visible = local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
    return '$visible•••$domain';
  }
}
