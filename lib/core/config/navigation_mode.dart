enum AppNavigationMode {
  sidebar,
  dashboardLauncher;

  String get displayName {
    switch (this) {
      case AppNavigationMode.sidebar:
        return 'Sidebar Navigation';
      case AppNavigationMode.dashboardLauncher:
        return 'Dashboard Launcher';
    }
  }

  static AppNavigationMode fromString(String? value) {
    if (value == 'dashboardLauncher') return AppNavigationMode.dashboardLauncher;
    return AppNavigationMode.sidebar;
  }
}
