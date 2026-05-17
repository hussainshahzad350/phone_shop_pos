import 'package:phone_shop_pos/core/constants/app_constants.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig._();

  static const String appName = AppConstants.appDisplayName;
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
    defaultValue: '1',
  );
  static const bool enableDemoSeedData = bool.fromEnvironment(
    'POS_ENABLE_DEMO_SEED',
    defaultValue: true,
  );

  static String get fullVersion => '$appVersion+$buildNumber';
}
