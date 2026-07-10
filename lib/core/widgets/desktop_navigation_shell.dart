import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/config/business_configuration_providers.dart';
import 'package:phone_shop_pos/core/config/business_profile.dart';
import 'package:phone_shop_pos/core/config/feature_access.dart';
import 'package:phone_shop_pos/core/routing/current_route_provider.dart';
import 'package:phone_shop_pos/core/routing/navigation_leave_guard.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/keyboard_shortcuts_dialog.dart';
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
  BusinessProfile profile = BusinessProfile.mobileOnly,
}) {
  final navItems = desktopNavigationItemsForProfile(profile);
  final selectedIndex = navItems.indexWhere(
    (item) =>
        desktopRouteMatches(currentPath: currentPath, routePrefix: item.route),
  );
  return selectedIndex < 0 ? 0 : selectedIndex;
}

String desktopNavigationLabelForPath(
  String currentPath, {
  BusinessProfile profile = BusinessProfile.mobileOnly,
}) {
  final navItems = desktopNavigationItemsForProfile(profile);
  return navItems
      .firstWhere(
        (item) => desktopRouteMatches(
            currentPath: currentPath, routePrefix: item.route),
        orElse: () => navItems.first,
      )
      .label;
}

List<DesktopNavigationItem> desktopNavigationItemsForProfile(
  BusinessProfile profile,
) {
  return _desktopNavItems
      .where(
        (item) => routeEnabledForProfile(
          path: item.route,
          profile: profile,
        ),
      )
      .toList(growable: false);
}

class DesktopNavigationShell extends ConsumerStatefulWidget {
  const DesktopNavigationShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  @override
  ConsumerState<DesktopNavigationShell> createState() =>
      _DesktopNavigationShellState();
}

class _DesktopNavigationShellState
    extends ConsumerState<DesktopNavigationShell> {
  @override
  void initState() {
    super.initState();
    _syncRouteState(widget.currentPath);
  }

  @override
  void didUpdateWidget(DesktopNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _syncRouteState(widget.currentPath);
    }
  }

  void _syncRouteState(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(scannerControllerProvider.notifier)
          .setActiveMode(ScannerModePath.fromPath(path));
      ref.read(currentRoutePathProvider.notifier).state = path;
    });
  }

  Future<void> _handleDestinationSelection(
    int index,
    List<DesktopNavigationItem> navItems,
  ) async {
    final targetPath = navItems[index].route;
    final shouldProceed = await confirmAndHandleCartLeave(
      context: context,
      ref: ref,
      currentPath: widget.currentPath,
      targetPath: targetPath,
    );
    if (!shouldProceed || !mounted) return;
    context.go(targetPath);
  }

  @override
  Widget build(BuildContext context) {
    // Only watch businessProfileProvider here — it rarely changes and drives
    // the sidebar items. Print/operations watches are isolated to child widgets.
    final profile =
        ref.watch(businessProfileProvider.select((v) => v.valueOrNull)) ??
            BusinessProfile.mobileOnly;
    final navItems = desktopNavigationItemsForProfile(profile);
    final selectedIndex = desktopNavigationSelectedIndexForPath(
      widget.currentPath,
      profile: profile,
    );
    final currentLabel = desktopNavigationLabelForPath(
      widget.currentPath,
      profile: profile,
    );

    return AppShortcutManager(
      child: AppDesktopScaffold(
        sidebar: AppSidebar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) =>
              _handleDestinationSelection(i, navItems),
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
          trailing: const Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              // Individual F5/F10 hint chips were removed: the full list now
              // lives behind the ? button (_ShortcutsHelpButton) / F1.
              _PendingPrintJobChip(),
              _ActiveOperationsChip(),
              _VersionChip(),
              _ShortcutsHelpButton(),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: widget.child),
            const GlobalScannerInput(),
          ],
        ),
      ),
    );
  }
}

// Each chip watches its own provider independently — a print-job change only
// rebuilds _PendingPrintJobChip, not the entire navigation shell.

class _PendingPrintJobChip extends ConsumerWidget {
  const _PendingPrintJobChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingPrintJobCountProvider);
    if (count == 0) return const SizedBox.shrink();
    return Chip(
      avatar: const Icon(Icons.print_outlined, size: 16),
      label: Text(
        'Pending prints: $count',
        style: const TextStyle(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ActiveOperationsChip extends ConsumerWidget {
  const _ActiveOperationsChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.watch(activeCriticalOperationsProvider);
    if (ops.isEmpty) return const SizedBox.shrink();
    return Chip(
      avatar: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: Text(
        ops.length == 1
            ? (ops.first.progressLabel ?? ops.first.label)
            : '${ops.length} active operations',
        style: const TextStyle(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ShortcutsHelpButton extends StatelessWidget {
  const _ShortcutsHelpButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 18),
      tooltip: 'Keyboard shortcuts (F1)',
      visualDensity: VisualDensity.compact,
      onPressed: () => KeyboardShortcutsDialog.show(context),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip();

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        'v${AppRuntimeConfig.fullVersion}',
        style: const TextStyle(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
