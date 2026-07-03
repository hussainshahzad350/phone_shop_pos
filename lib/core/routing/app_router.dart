import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';
import 'package:phone_shop_pos/core/widgets/desktop_navigation_shell.dart';
import 'package:phone_shop_pos/core/widgets/route_reset_boundary.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/brand_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/product_management_providers.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_filter_providers.dart';
import 'package:phone_shop_pos/modules/reports/application/providers/report_state_providers.dart';
import 'package:phone_shop_pos/modules/repairing/presentation/providers/repairing_providers.dart';
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
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
            const SizedBox(height: AppSpacing.sm),
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
      // Redirect-only routes live at the top level (they render no screen).
      GoRoute(
        path: '/',
        redirect: (context, state) => '/welcome',
      ),
      GoRoute(
        path: '/customers',
        redirect: (context, state) => '/sales',
      ),
      // Each navigable screen is its own branch so its widget/state is kept
      // alive in an IndexedStack instead of being rebuilt on every tab switch.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => DesktopNavigationShell(
          currentPath: state.uri.path,
          child: navigationShell,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const RouteResetBoundary(
                  routePath: '/dashboard',
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesBillingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/purchases',
                builder: (context, state) => const PurchaseScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const RouteResetBoundary(
                  routePath: '/inventory',
                  child: InventoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/master-data',
                builder: (context, state) => RouteResetBoundary(
                  routePath: '/master-data',
                  onReset: (ref) {
                    ref.invalidate(brandSearchQueryProvider);
                    ref.invalidate(brandIncludeInactiveProvider);
                    ref.invalidate(productManagementSearchQueryProvider);
                    ref.invalidate(productManagementTypeFilterProvider);
                  },
                  child: const MasterDataScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/dealer-issues',
                builder: (context, state) => const RouteResetBoundary(
                  routePath: '/dealer-issues',
                  child: DealerIssueScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/repairing',
                builder: (context, state) => RouteResetBoundary(
                  routePath: '/repairing',
                  onReset: (ref) {
                    ref.invalidate(repairJobsSearchQueryProvider);
                    ref.invalidate(repairJobsStatusFilterProvider);
                  },
                  child: const RepairingScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/reports',
                builder: (context, state) => RouteResetBoundary(
                  routePath: '/reports',
                  onReset: (ref) {
                    ref.invalidate(selectedReportsTabProvider);
                    ref.invalidate(reportFilterProvider);
                  },
                  child: const ReportsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);
