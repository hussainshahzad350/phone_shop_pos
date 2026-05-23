import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_process_feedback.dart';

class ScannerSessionState {
  const ScannerSessionState({
    this.activeMode,
    this.isProcessing = false,
    this.fastModeEnabled = true,
    this.fastBillingActive = false,
    this.processedValues = const <String>{},
    this.lastFeedback,
    this.sequence = 0,
  });

  final ScannerMode? activeMode;
  final bool isProcessing;
  final bool fastModeEnabled;
  final bool fastBillingActive;
  final Set<String> processedValues;
  final ScannerProcessFeedback? lastFeedback;
  final int sequence;

  ScannerSessionState copyWith({
    ScannerMode? activeMode,
    bool clearActiveMode = false,
    bool? isProcessing,
    bool? fastModeEnabled,
    bool? fastBillingActive,
    Set<String>? processedValues,
    ScannerProcessFeedback? lastFeedback,
    bool clearLastFeedback = false,
    int? sequence,
  }) {
    return ScannerSessionState(
      activeMode: clearActiveMode ? null : activeMode ?? this.activeMode,
      isProcessing: isProcessing ?? this.isProcessing,
      fastModeEnabled: fastModeEnabled ?? this.fastModeEnabled,
      fastBillingActive: fastBillingActive ?? this.fastBillingActive,
      processedValues: processedValues ?? this.processedValues,
      lastFeedback:
          clearLastFeedback ? null : lastFeedback ?? this.lastFeedback,
      sequence: sequence ?? this.sequence,
    );
  }
}
