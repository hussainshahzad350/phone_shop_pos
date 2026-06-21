enum BusinessProfile {
  mobileOnly,
  mobileAccessories,
  repairShop,
  hybrid;

  String get displayName {
    switch (this) {
      case BusinessProfile.mobileOnly:
        return 'Mobile Only';
      case BusinessProfile.mobileAccessories:
        return 'Mobile + Accessories';
      case BusinessProfile.repairShop:
        return 'Repair Shop';
      case BusinessProfile.hybrid:
        return 'Hybrid';
    }
  }

  String get description {
    switch (this) {
      case BusinessProfile.mobileOnly:
        return 'Mobile phones only - fast, focused workflow';
      case BusinessProfile.mobileAccessories:
        return 'Mobile phones and accessories - broader inventory';
      case BusinessProfile.repairShop:
        return 'Repair services included - multi-service shop';
      case BusinessProfile.hybrid:
        return 'Full service - phones, accessories, and repairs';
    }
  }

  static const BusinessProfile defaultProfile = BusinessProfile.mobileOnly;

  static BusinessProfile? tryParse(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final profile in BusinessProfile.values) {
      if (profile.name == normalized) {
        return profile;
      }
    }
    return null;
  }

  static BusinessProfile parseOrDefault(String? value) {
    return tryParse(value) ?? defaultProfile;
  }
}
