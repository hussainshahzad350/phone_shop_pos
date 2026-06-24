import 'package:phone_shop_pos/core/config/business_profile.dart';

enum BusinessConfigurationSource {
  defaultValue,
  persisted,
  mixed,
}

class BusinessConfiguration {
  const BusinessConfiguration({
    required this.profile,
    required this.source,
    required this.schemaVersion,
    required this.loadedAt,
  });

  static const int currentSchemaVersion = 1;

  final BusinessProfile profile;
  final BusinessConfigurationSource source;
  final int schemaVersion;
  final DateTime loadedAt;

  factory BusinessConfiguration.defaults({DateTime? loadedAt}) {
    return BusinessConfiguration(
      profile: BusinessProfile.mobileOnly,
      source: BusinessConfigurationSource.defaultValue,
      schemaVersion: currentSchemaVersion,
      loadedAt: loadedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  BusinessConfiguration copyWith({
    BusinessProfile? profile,
    BusinessConfigurationSource? source,
    int? schemaVersion,
    DateTime? loadedAt,
  }) {
    return BusinessConfiguration(
      profile: profile ?? this.profile,
      source: source ?? this.source,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }
}
