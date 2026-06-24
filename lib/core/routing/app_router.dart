import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';
import 'package:phone_shop_pos/core/widgets/desktop_navigation_shell.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/auth/presentation/screens/login_screen.dart';
import 'package:phone_shop_pos/modules/auth/presentation/screens/welcome_screen.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/screens/inventory_screen.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/screens/master_data_screen.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/screens/purchase_screen.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/screens/dealer_issue_screen.dart';
import 'package:phone_shop_pos/modules/repairing/presentation/screens/repairing_screen.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/reports_screen.dart';
import 'package:phone_shop_pos/modules/sales/presentation/screens/sales_billing_screen.dart';
import 'package:phone_shop_pos/modules/settings/presentation/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final navigatorKey = ref.watch(rootNavigatorKeyProvider);
  final isAuthInitialized = ref.watch(
    localPinAuthControllerProvider.select((state) => state.isInitialized),
  );
  final hasPinConfigured = ref.watch(
    localPinAuthControllerProvider.select((state) => state.hasPinConfigured),
  );
  final isAuthenticated = ref.watch(
    localPinAuthControllerProvider.select((state) => state.isAuthenticated),
  );
  final profile = ref.watch(businessProfileProvider).valueOrNull ??
      BusinessProfile.mobileOnly;
  return GoRouter(
    navigatorKey: navigatorKey,
    redirect: (context, state) {
      final path = state.uri.path;
      final onPublicRoute = path == '/welcome' || path == '/login';

      if (!isAuthInitialized) {
        return onPublicRoute ? null : '/login';
      }

      if (!hasPinConfigured) {
        return onPublicRoute ? null : '/login';
      }

      if (!isAuthenticated) {
        return onPublicRoute ? null : '/login';
      }

      if (onPublicRoute) {
        return '/dashboard';
      }
      if (!routeEnabledForProfile(path: path, profile: profile)) {
        return profileRouteFallback(profile);
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Navigation error. Returning to dashboard.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => GoRouter.of(context).go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DesktopNavigationShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            redirect: (context, state) => '/welcome',
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
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
            path: '/master-data',
            builder: (context, state) => const MasterDataScreen(),
          ),
          GoRoute(
            path: '/customers',
            redirect: (context, state) => '/sales',
          ),
          GoRoute(
            path: '/dealer-issues',
            builder: (context, state) => const DealerIssueScreen(),
          ),
          GoRoute(
            path: '/repairing',
            builder: (context, state) => const RepairingScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);
