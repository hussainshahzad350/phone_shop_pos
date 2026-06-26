import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_process_feedback.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/providers/scanner_providers.dart';

class GlobalScannerInput extends ConsumerStatefulWidget {
  const GlobalScannerInput({super.key});

  @override
  ConsumerState<GlobalScannerInput> createState() => _GlobalScannerInputState();
}

class _GlobalScannerInputState extends ConsumerState<GlobalScannerInput>
    with WidgetsBindingObserver {
  static const Key scannerInputKey = Key('global-scanner-input');
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _focusTimer;
  int _lastFeedbackSequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _restoreFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _reclaimFocusAfterLifecycleEvent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reclaimFocusAfterLifecycleEvent();
    }
  }

  void _restoreFocus() {
    if (!mounted) return;
    // Reclaim only when nothing user-interactive holds focus. A FocusScopeNode
    // as primaryFocus means focus was released (e.g. via unfocus()) but no
    // leaf widget has it — treat that the same as null so the scanner reclaims.
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _focusNode || primary is FocusScopeNode) {
      _focusNode.requestFocus();
    }
  }

  // Force-reclaim focus regardless of what holds it. Used only for lifecycle
  // events (app resume, screen metrics change) where the OS may have dropped
  // focus from the scanner without any user input having taken it.
  void _reclaimFocusAfterLifecycleEvent() {
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  Future<void> _submit(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      _controller.clear();
      _restoreFocus();
      return;
    }
    await ref.read(scannerControllerProvider.notifier).submitRawScan(value);
    _controller.clear();
    _restoreFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scannerControllerProvider, (previous, next) {
      final feedback = next.lastFeedback;
      if (feedback == null || next.sequence == _lastFeedbackSequence) {
        return;
      }
      _lastFeedbackSequence = next.sequence;
      switch (feedback.severity) {
        case ScannerFeedbackSeverity.success:
          if (feedback.code == 'sales_finish_scan') {
            AppNotifier.success(feedback.message);
          }
          break;
        case ScannerFeedbackSeverity.warning:
          AppNotifier.warning(feedback.message);
          break;
        case ScannerFeedbackSeverity.error:
          AppNotifier.error(feedback.message);
          break;
      }
      _restoreFocus();
    });

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: scannerInputKey,
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) {
                // Focus reclamation is handled by the periodic timer.
                // Do not steal immediately so the user can interact with
                // manual input fields between timer ticks.
              },
              onSubmitted: _submit,
              onEditingComplete: _restoreFocus,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
        ),
      ),
    );
  }
}
