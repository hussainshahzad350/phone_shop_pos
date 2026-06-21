import 'package:phone_shop_pos/core/config/feature_flags.dart';

bool routeEnabledForFeatureFlags({
  required String path,
  required FeatureFlags featureFlags,
}) {
  final normalizedPath = normalizeRoutePath(path);
  if (_routeMatches(normalizedPath, '/repairing')) {
    return featureFlags.repairModule;
  }
  if (_routeMatches(normalizedPath, '/reports')) {
    return featureFlags.reports;
  }
  if (_routeMatches(normalizedPath, '/inventory')) {
    return featureFlags.imeiStock || featureFlags.qtyStock;
  }
  return true;
}

String featureFlagRouteFallback(FeatureFlags featureFlags) {
  if (routeEnabledForFeatureFlags(
    path: '/dashboard',
    featureFlags: featureFlags,
  )) {
    return '/dashboard';
  }
  return '/settings';
}

String normalizeRoutePath(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '/';
  }
  final parsed = Uri.tryParse(trimmed);
  var path = parsed?.path ?? trimmed.split('?').first.split('#').first;
  if (path.isEmpty) {
    path = '/';
  }
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

bool _routeMatches(String currentPath, String routePrefix) {
  final normalizedPath = normalizeRoutePath(currentPath);
  final normalizedPrefix = normalizeRoutePath(routePrefix);
  return normalizedPath == normalizedPrefix ||
      normalizedPath.startsWith('$normalizedPrefix/');
}
