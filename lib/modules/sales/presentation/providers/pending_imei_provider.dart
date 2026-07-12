import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When non-null, the Sales screen will auto-search and add this IMEI to the
/// cart as soon as the screen mounts or the value changes.  Set by the Reports
/// IMEI-search "Sell This" button; cleared by the sales screen after use.
final pendingImeiAutoAddProvider = StateProvider<String?>((ref) => null);
