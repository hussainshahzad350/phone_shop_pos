import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/modules/auth/services/local_pin_auth_service.dart';

class LocalPinAuthState {
  const LocalPinAuthState({
    required this.isInitialized,
    required this.isBusy,
    required this.hasPinConfigured,
    required this.isAuthenticated,
    required this.failedAttempts,
    this.lockedUntil,
    this.errorMessage,
  });

  const LocalPinAuthState.initial()
      : isInitialized = false,
        isBusy = false,
        hasPinConfigured = false,
        isAuthenticated = false,
        failedAttempts = 0,
        lockedUntil = null,
        errorMessage = null;

  final bool isInitialized;
  final bool isBusy;
  final bool hasPinConfigured;
  final bool isAuthenticated;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? errorMessage;

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  LocalPinAuthState copyWith({
    bool? isInitialized,
    bool? isBusy,
    bool? hasPinConfigured,
    bool? isAuthenticated,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LocalPinAuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBusy: isBusy ?? this.isBusy,
      hasPinConfigured: hasPinConfigured ?? this.hasPinConfigured,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LocalPinAuthController extends StateNotifier<LocalPinAuthState> {
  LocalPinAuthController(this._service) : super(const LocalPinAuthState.initial()) {
    _initialize();
  }

  final LocalPinAuthService _service;
  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(seconds: 60);
  static final RegExp _pinPattern = RegExp(r'^\d{4,6}$');

  Future<void> _initialize() async {
    final hasPin = await _service.hasPinConfigured();
    state = state.copyWith(
      isInitialized: true,
      hasPinConfigured: hasPin,
      clearErrorMessage: true,
    );
  }

  String? validatePin(String pin) {
    if (!_pinPattern.hasMatch(pin)) {
      return 'PIN must be 4 to 6 digits.';
    }
    return null;
  }

  Future<String?> setupPin({
    required String pin,
    required String confirmPin,
  }) async {
    if (state.hasPinConfigured) {
      state = state.copyWith(
        errorMessage: 'PIN is already set. Use Change PIN in Settings.',
      );
      return null;
    }
    final pinError = validatePin(pin);
    if (pinError != null) {
      state = state.copyWith(errorMessage: pinError);
      return null;
    }
    if (pin != confirmPin) {
      state = state.copyWith(errorMessage: 'PIN confirmation does not match.');
      return null;
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    try {
      final recoveryCode = await _service.configurePin(pin);
      state = state.copyWith(
        isBusy: false,
        hasPinConfigured: true,
        isAuthenticated: true,
        failedAttempts: 0,
        clearLockedUntil: true,
      );
      return recoveryCode;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Could not save PIN. Please try again.',
      );
      return null;
    }
  }

  Future<bool> loginWithPin(String pin) async {
    if (!state.hasPinConfigured) {
      state = state.copyWith(errorMessage: 'Set up a PIN first.');
      return false;
    }
    final pinError = validatePin(pin);
    if (pinError != null) {
      state = state.copyWith(errorMessage: pinError);
      return false;
    }

    final now = DateTime.now();
    if (state.lockedUntil != null && now.isBefore(state.lockedUntil!)) {
      final remaining = state.lockedUntil!.difference(now).inSeconds + 1;
      state = state.copyWith(
        errorMessage: 'Too many wrong attempts. Try again in ${remaining}s.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    final valid = await _service.verifyPin(pin);
    if (valid) {
      state = state.copyWith(
        isBusy: false,
        isAuthenticated: true,
        failedAttempts: 0,
        clearLockedUntil: true,
      );
      return true;
    }

    final nextAttempts = state.failedAttempts + 1;
    if (nextAttempts >= _maxAttempts) {
      final lockedUntil = DateTime.now().add(_lockDuration);
      state = state.copyWith(
        isBusy: false,
        failedAttempts: _maxAttempts,
        lockedUntil: lockedUntil,
        errorMessage: 'Too many wrong attempts. Login is locked for 60 seconds.',
      );
      return false;
    }

    state = state.copyWith(
      isBusy: false,
      failedAttempts: nextAttempts,
      errorMessage: 'Invalid PIN. ${_maxAttempts - nextAttempts} attempts left.',
    );
    return false;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final pinError = validatePin(newPin);
    if (pinError != null) {
      state = state.copyWith(errorMessage: pinError);
      return false;
    }
    if (newPin != confirmPin) {
      state = state.copyWith(errorMessage: 'New PIN confirmation does not match.');
      return false;
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    final changed = await _service.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );
    state = state.copyWith(
      isBusy: false,
      errorMessage: changed ? null : 'Current PIN is incorrect.',
    );
    return changed;
  }

  Future<bool> resetPinWithRecoveryCode({
    required String recoveryCode,
    required String newPin,
    required String confirmPin,
  }) async {
    final pinError = validatePin(newPin);
    if (pinError != null) {
      state = state.copyWith(errorMessage: pinError);
      return false;
    }
    if (newPin != confirmPin) {
      state = state.copyWith(errorMessage: 'New PIN confirmation does not match.');
      return false;
    }
    if (recoveryCode.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Recovery code is required.');
      return false;
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    final reset = await _service.resetPinWithRecoveryCode(
      recoveryCode: recoveryCode.trim().toUpperCase(),
      newPin: newPin,
    );
    state = state.copyWith(
      isBusy: false,
      isAuthenticated: false,
      failedAttempts: 0,
      clearLockedUntil: true,
      errorMessage: reset ? null : 'Recovery code is invalid.',
    );
    return reset;
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}

final localPinAuthServiceProvider = Provider<LocalPinAuthService>((ref) {
  final appDatabase = ref.watch(appDatabaseProvider).requireValue;
  return LocalPinAuthService(appDatabase: appDatabase);
});

final localPinAuthControllerProvider =
    StateNotifierProvider<LocalPinAuthController, LocalPinAuthState>((ref) {
  final service = ref.watch(localPinAuthServiceProvider);
  return LocalPinAuthController(service);
});
