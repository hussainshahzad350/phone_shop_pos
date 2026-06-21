import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';
import 'package:phone_shop_pos/core/config/feature_flags.dart';
import 'package:phone_shop_pos/core/routing/navigation_leave_guard.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/modules/scanner/domain/entities/scanner_mode.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/providers/scanner_providers.dart';
import 'package:phone_shop_pos/modules/scanner/presentation/widgets/global_scanner_input.dart';

bool desktopRouteMatches({
  required String currentPath,
  required String routePrefix,
}) {
  final normalizedPath = normalizeRoutePath(currentPath);
  final normalizedPrefix = normalizeRoutePath(routePrefix);
  return normalizedPath == normalizedPrefix ||
      normalizedPath.startsWith('$normalizedPrefix/');
}

int desktopNavigationSelectedIndexForPath(
  String currentPath, {
  FeatureFlags featureFlags = const FeatureFlags.currentBehaviorDefaults(),
}) {
  final navItems = desktopNavigationItemsForFlags(featureFlags);
  final selectedIndex = navItems.indexWhere(
    (item) =>
        desktopRouteMatches(currentPath: currentPath, routePrefix: item.route),
  );
  return selectedIndex < 0 ? 0 : selectedIndex;
}

String desktopNavigationLabelForPath(
  String currentPath, {
  FeatureFlags featureFlags = const FeatureFlags.currentBehaviorDefaults(),
}) {
  final navItems = desktopNavigationItemsForFlags(featureFlags);
  return navItems
      .firstWhere(
        (item) => desktopRouteMatches(
            currentPath: currentPath, routePrefix: item.route),
        orElse: () => navItems.first,
      )
      .label;
}

List<DesktopNavigationItem> desktopNavigationItemsForFlags(
  FeatureFlags featureFlags,
) {
  return _desktopNavItems
      .where(
        (item) => routeEnabledForFeatureFlags(
          path: item.route,
          featureFlags: featureFlags,
        ),
      )
      .toList(growable: false);
}

class DesktopNavigationShell extends ConsumerWidget {
  const DesktopNavigationShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOperations = ref.watch(activeCriticalOperationsProvider);
    final pendingPrintJobs = ref.watch(pendingPrintJobCountProvider);
    final featureFlags = ref.watch(featureFlagsProvider).valueOrNull ??
        const FeatureFlags.currentBehaviorDefaults();
    final navItems = desktopNavigationItemsForFlags(featureFlags);
    final selectedIndex = desktopNavigationSelectedIndexForPath(
      currentPath,
      featureFlags: featureFlags,
    );
    final currentLabel = desktopNavigationLabelForPath(
      currentPath,
      featureFlags: featureFlags,
    );
    final scannerMode = ScannerModePath.fromPath(currentPath);
    final scannerController = ref.read(scannerControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scannerController.setActiveMode(scannerMode);
    });

    Future<void> handleDestinationSelection(int index) async {
      final targetPath = navItems[index].route;
      final shouldProceed = await confirmAndHandleCartLeave(
        context: context,
        ref: ref,
        currentPath: currentPath,
        targetPath: targetPath,
      );
      if (!shouldProceed || !context.mounted) {
        return;
      }
      context.go(targetPath);
    }

    return AppShortcutManager(
      child: AppDesktopScaffold(
        sidebar: AppSidebar(
          selectedIndex: selectedIndex,
          onDestinationSelected: handleDestinationSelection,
          destinations: navItems
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                ),
              )
              .toList(growable: false),
        ),
        topBar: AppTopBar(
          title: currentLabel,
          trailing: Wrap(
            spacing: 6,
            children: <Widget>[
              const AppShortcutHint(label: 'Search', shortcut: 'F1 / Ctrl+F'),
              const AppShortcutHint(label: 'Refresh', shortcut: 'F5'),
              const AppShortcutHint(label: 'Save', shortcut: 'F10'),
              if (pendingPrintJobs > 0)
                Chip(
                  avatar: const Icon(Icons.print_outlined, size: 16),
                  label: Text(
                    'Pending prints: $pendingPrintJobs',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (activeOperations.isNotEmpty)
                Chip(
                  avatar: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text(
                    activeOperations.length == 1
                        ? (activeOperations.first.progressLabel ??
                            activeOperations.first.label)
                        : '${activeOperations.length} active operations',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              Chip(
                label: Text(
                  'v${AppRuntimeConfig.fullVersion}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: child),
            const GlobalScannerInput(),
          ],
        ),
      ),
    );
  }
}

class DesktopNavigationItem {
  const DesktopNavigationItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

const List<DesktopNavigationItem> _desktopNavItems = <DesktopNavigationItem>[
  DesktopNavigationItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/dashboard',
  ),
  DesktopNavigationItem(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    route: '/sales',
  ),
  DesktopNavigationItem(
    label: 'Purchases',
    icon: Icons.shopping_cart_outlined,
    route: '/purchases',
  ),
  DesktopNavigationItem(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    route: '/inventory',
  ),
  DesktopNavigationItem(
    label: 'Master Data',
    icon: Icons.dataset_outlined,
    route: '/master-data',
  ),
  DesktopNavigationItem(
    label: 'Repairing',
    icon: Icons.build_outlined,
    route: '/repairing',
  ),
  DesktopNavigationItem(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    route: '/reports',
  ),
  DesktopNavigationItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    route: '/settings',
  ),
];
