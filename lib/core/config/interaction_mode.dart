enum AppInteractionMode {
  desktop,
  touch;

  String get displayName {
    switch (this) {
      case AppInteractionMode.desktop:
        return 'Desktop (mouse & keyboard)';
      case AppInteractionMode.touch:
        return 'Touch';
    }
  }

  static AppInteractionMode fromString(String? value) {
    if (value == 'touch') return AppInteractionMode.touch;
    return AppInteractionMode.desktop;
  }
}
