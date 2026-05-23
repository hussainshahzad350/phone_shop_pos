import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_process_feedback.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_session_state.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_mode_router.dart';
import 'package:phone_shop_pos/modules/scanner/services/scanner_service.dart';

class ScannerController extends StateNotifier<ScannerSessionState> {
  ScannerController({
    required ScannerService scannerService,
    required ScannerModeRouter modeRouter,
  })  : _scannerService = scannerService,
        _modeRouter = modeRouter,
        super(const ScannerSessionState());

  final ScannerService _scannerService;
  final ScannerModeRouter _modeRouter;
  Future<void> _processingChain = Future<void>.value();

  void setActiveMode(ScannerMode? mode) {
    final previous = state.activeMode;
    if (previous == mode) {
      return;
    }
    state = state.copyWith(
      activeMode: mode,
      clearActiveMode: mode == null,
      processedValues: const <String>{},
      fastBillingActive: false,
    );
  }

  void setFastModeEnabled(bool enabled) {
    state = state.copyWith(fastModeEnabled: enabled);
  }

  void resetSession() {
    state = state.copyWith(
      processedValues: const <String>{},
      fastBillingActive: false,
    );
  }

  Future<void> submitRawScan(String rawValue) {
    _processingChain = _processingChain.then((_) => _process(rawValue));
    return _processingChain;
  }

  Future<void> _process(String rawValue) async {
    state = state.copyWith(isProcessing: true);

    final mode = state.activeMode;
    if (mode == null) {
      _emitFeedback(
        const ScannerProcessFeedback(
          code: 'scanner_mode_inactive',
          message: 'Scanner is inactive on this screen.',
          severity: ScannerFeedbackSeverity.warning,
        ),
      );
      state = state.copyWith(isProcessing: false);
      return;
    }

    final validation = _scannerService.normalizeAndValidate(rawValue);
    if (!validation.isValid || validation.payload == null) {
      _emitFeedback(
        ScannerProcessFeedback(
          code: validation.errorCode ?? 'invalid_scan',
          message: validation.errorMessage ?? 'Invalid scan input.',
          severity: ScannerFeedbackSeverity.error,
        ),
      );
      state = state.copyWith(isProcessing: false);
      return;
    }

    final payload = validation.payload!;

    if (!payload.isFinishCode && state.processedValues.contains(payload.normalizedValue)) {
      _emitFeedback(
        ScannerProcessFeedback(
          code: 'duplicate_scan',
          message: 'Duplicate scan blocked for current session.',
          severity: ScannerFeedbackSeverity.warning,
          processedValue: payload.normalizedValue,
        ),
      );
      state = state.copyWith(isProcessing: false);
      return;
    }

    final result = await _modeRouter.route(mode: mode, payload: payload);

    final nextProcessedValues = result.resetSession
        ? const <String>{}
        : <String>{...state.processedValues, payload.normalizedValue};

    final shouldActivateFastBilling =
        mode == ScannerMode.sales && state.fastModeEnabled && result.isSuccess;

    state = state.copyWith(
      isProcessing: false,
      processedValues: nextProcessedValues,
      fastBillingActive: result.resetSession
          ? false
          : (result.activateFastBilling ||
              state.fastBillingActive ||
              shouldActivateFastBilling),
    );

    _emitFeedback(
      ScannerProcessFeedback(
        code: result.code,
        message: result.message,
        severity: result.isSuccess
            ? (result.isWarning
                ? ScannerFeedbackSeverity.warning
                : ScannerFeedbackSeverity.success)
            : ScannerFeedbackSeverity.error,
        processedValue: payload.normalizedValue,
      ),
    );
  }

  void _emitFeedback(ScannerProcessFeedback feedback) {
    state = state.copyWith(
      lastFeedback: feedback,
      sequence: state.sequence + 1,
    );
  }
}
