import 'package:flutter/foundation.dart';

import 'package:phone_shop_pos/core/constants/app_constants.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig._();

  static const String appName = AppConstants.appDisplayName;
  static const String developerName = AppConstants.developerName;
  static const String contactPhone = AppConstants.contactPhone;
  static const String contactEmail = AppConstants.contactEmail;
  static const String contactAddress = AppConstants.contactAddress;
  static const String releaseChannel = String.fromEnvironment(
    'POS_RELEASE_CHANNEL',
    defaultValue: 'beta',
  );
  static const String appVersion = String.fromEnvironment(
    'POS_APP_VERSION',
    defaultValue: '0.1.0',
  );
  static const String buildNumber = String.fromEnvironment(
    'POS_BUILD_NUMBER',
    defaultValue: '2',
  );
  // Feature flag for seed/demo data. Enabled in debug/local runs only.
  static const bool kEnableSeedData = kDebugMode ||
      bool.fromEnvironment(
        'POS_ENABLE_SEED_DATA',
        defaultValue: false,
      );
  static const int autoBackupIntervalHours = int.fromEnvironment(
    'POS_AUTO_BACKUP_INTERVAL_HOURS',
    defaultValue: 24,
  );

  static String get fullVersion => '$appVersion+$buildNumber';
  static String get contactSummary => '$contactPhone | $contactEmail';
}
