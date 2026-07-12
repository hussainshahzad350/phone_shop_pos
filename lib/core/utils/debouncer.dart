import 'dart:async';
import 'dart:ui';

import 'package:phone_shop_pos/core/theme/app_motion.dart';

/// Cancels and restarts a delayed callback on every [run] call — the debounce
/// pattern every search box in this app previously hand-rolled as its own
/// `Timer?` field. Callers own the instance's lifetime and must call
/// [dispose] (e.g. from `State.dispose`) to cancel any pending callback.
class Debouncer {
  Debouncer({this.delay = AppMotion.defaultDebounce});

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}
