import 'package:phone_shop_pos/core/config/business_profile.dart';

bool routeEnabledForProfile({
  required String path,
  required BusinessProfile profile,
}) {
  return true;
}

String profileRouteFallback(BusinessProfile profile) {
  return '/dashboard';
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
