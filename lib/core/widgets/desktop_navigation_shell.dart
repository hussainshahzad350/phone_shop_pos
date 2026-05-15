import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class DesktopNavigationShell extends ConsumerWidget {
  const DesktopNavigationShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    _NavItem(label: 'Sales', icon: Icons.point_of_sale_outlined, route: '/sales'),
    _NavItem(label: 'Purchases', icon: Icons.shopping_cart_outlined, route: '/purchases'),
    _NavItem(label: 'Inventory', icon: Icons.inventory_2_outlined, route: '/inventory'),
    _NavItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/reports'),
    _NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _items.indexWhere((item) => currentPath == item.route);
    final currentLabel = _items
        .firstWhere(
          (item) => item.route == currentPath,
          orElse: () => _items.first,
        )
        .label;

    return AppShortcutManager(
      child: AppDesktopScaffold(
        sidebar: AppSidebar(
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onDestinationSelected: (index) {
            context.go(_items[index].route);
          },
          destinations: _items
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
          trailing: const Wrap(
            spacing: 6,
            children: <Widget>[
              AppShortcutHint(label: 'Search', shortcut: 'F1 / Ctrl+F'),
              AppShortcutHint(label: 'Refresh', shortcut: 'F5'),
              AppShortcutHint(label: 'Save', shortcut: 'F10'),
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
