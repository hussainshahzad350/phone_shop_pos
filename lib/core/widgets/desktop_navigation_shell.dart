import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DesktopNavigationShell extends StatelessWidget {
  const DesktopNavigationShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/'),
    _NavItem(label: 'Sales', icon: Icons.point_of_sale_outlined, route: '/sales'),
    _NavItem(label: 'Purchases', icon: Icons.shopping_cart_outlined, route: '/purchases'),
    _NavItem(label: 'Inventory', icon: Icons.inventory_2_outlined, route: '/inventory'),
    _NavItem(label: 'Customers', icon: Icons.people_outline, route: '/customers'),
    _NavItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/reports'),
    _NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _items.indexWhere((item) => currentPath == item.route);

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) {
              context.go(_items[index].route);
            },
            labelType: NavigationRailLabelType.all,
            destinations: _items
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(growable: false),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
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
