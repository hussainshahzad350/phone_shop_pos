import 'dart:async';

import 'package:flutter/foundation.dart';

class QueryDiagnostics {
  const QueryDiagnostics._();

  static const Duration slowQueryThreshold = Duration(milliseconds: 120);
  static const bool productionSlowQueryLogsEnabled = bool.fromEnvironment(
    'PHONE_SHOP_POS_SLOW_QUERY_LOGS',
    defaultValue: false,
  );

  static Future<T> trace<T>({
    required String label,
    required Future<T> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;
      final isSlow = elapsed >= slowQueryThreshold.inMilliseconds;
      if (kDebugMode || (productionSlowQueryLogsEnabled && isSlow)) {
        final prefix = isSlow ? '[slow-query]' : '[query]';
        _log('$prefix ${elapsed}ms $label');
      }
    }
  }

  static void _log(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(message);
  }
}
