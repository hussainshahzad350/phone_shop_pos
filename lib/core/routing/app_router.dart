import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/widgets/desktop_navigation_shell.dart';
import 'package:phone_shop_pos/core/widgets/module_placeholder_screen.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/screens/inventory_screen.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/screens/purchase_screen.dart';
import 'package:phone_shop_pos/modules/sales/presentation/screens/sales_billing_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => DesktopNavigationShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const ModulePlaceholderScreen(
              title: 'Dashboard',
            ),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesBillingScreen(),
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchaseScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const ModulePlaceholderScreen(
              title: 'Customers',
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ModulePlaceholderScreen(
              title: 'Reports',
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const ModulePlaceholderScreen(
              title: 'Settings',
            ),
          ),
        ],
      ),
    ],
  );
});
