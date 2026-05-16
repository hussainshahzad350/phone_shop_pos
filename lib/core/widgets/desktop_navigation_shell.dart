import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';

bool desktopRouteMatches({
  required String currentPath,
  required String routePrefix,
}) {
  final normalizedPath = _normalizeRoutePath(currentPath);
  final normalizedPrefix = _normalizeRoutePath(routePrefix);
  return normalizedPath == normalizedPrefix ||
      normalizedPath.startsWith('$normalizedPrefix/');
}

int desktopNavigationSelectedIndexForPath(String currentPath) {
  final selectedIndex = _desktopNavItems.indexWhere(
    (item) =>
        desktopRouteMatches(currentPath: currentPath, routePrefix: item.route),
  );
  return selectedIndex < 0 ? 0 : selectedIndex;
}

String desktopNavigationLabelForPath(String currentPath) {
  return _desktopNavItems
      .firstWhere(
        (item) =>
            desktopRouteMatches(currentPath: currentPath, routePrefix: item.route),
        orElse: () => _desktopNavItems.first,
      )
      .label;
}

String _normalizeRoutePath(String value) {
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
    final selectedIndex = desktopNavigationSelectedIndexForPath(currentPath);
    final currentLabel = desktopNavigationLabelForPath(currentPath);

    return AppShortcutManager(
      child: AppDesktopScaffold(
        sidebar: AppSidebar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            context.go(_desktopNavItems[index].route);
          },
          destinations: _desktopNavItems
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
        child: child,
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

const List<_NavItem> _desktopNavItems = <_NavItem>[
  _NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/dashboard',
  ),
  _NavItem(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    route: '/sales',
  ),
  _NavItem(
    label: 'Purchases',
    icon: Icons.shopping_cart_outlined,
    route: '/purchases',
  ),
  _NavItem(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    route: '/inventory',
  ),
  _NavItem(
    label: 'Master Data',
    icon: Icons.dataset_outlined,
    route: '/master-data',
  ),
  _NavItem(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    route: '/reports',
  ),
  _NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    route: '/settings',
  ),
];
