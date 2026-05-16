import 'dart:async';

import 'package:flutter/foundation.dart';

class QueryDiagnostics {
  const QueryDiagnostics._();

  static const Duration slowQueryThreshold = Duration(milliseconds: 120);

  static Future<T> trace<T>({
    required String label,
    required Future<T> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      if (kDebugMode) {
        final elapsed = stopwatch.elapsedMilliseconds;
        final prefix = elapsed >= slowQueryThreshold.inMilliseconds
            ? '[slow-query]'
            : '[query]';
        debugPrint('$prefix ${elapsed}ms $label');
      }
    }
  }
}
