import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_kpis_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/sidebar_insights_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/sidebar_insights_panel.dart';

void main() {
  const insights = SidebarInsightsEntity(
    topSellingBrand: 'Samsung',
    topSellingModel: 'Redmi 13C',
    topCustomer: 'Bilal Ahmed',
    topAccessory: 'Charger 20W',
    todaySalesCount: 2,
    todayPurchasesCount: 1,
  );
  const kpis = DashboardKpisEntity(
    todaySales: 107100,
    todayProfit: 8150,
    phonesSoldToday: 1,
    accessoriesSoldToday: 4,
    lowStockCount: 1,
    availableStockCount: 160,
    pendingBalances: 8850,
    totalStockWorth: 1091350,
  );

  Widget wrap(Widget sidebar) {
    return ProviderScope(
      overrides: <Override>[
        sidebarInsightsProvider.overrideWith((ref) async => insights),
        dashboardKpisProvider.overrideWith((ref) async => kpis),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              sidebar,
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
  }

  // Mirrors the trailing structure the navigation shell passes to AppSidebar.
  Widget shellTrailing() {
    return const Column(
      children: <Widget>[
        SizedBox(height: 16),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: SidebarInsightsPanel(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SidebarTodaySummaryCard(),
        ),
      ],
    );
  }

  testWidgets(
      'extended AppSidebar with insights trailing lays out at extended width '
      'without layout exceptions', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        AppSidebar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              label: Text('Sales'),
            ),
          ],
          trailing: shellTrailing(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final railSize = tester.getSize(find.byType(NavigationRail));
    expect(railSize.width, greaterThanOrEqualTo(208));
    expect(find.text('Samsung'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('narrow AppSidebar hides trailing and keeps compact width',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        AppSidebar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              label: Text('Sales'),
            ),
          ],
          trailing: shellTrailing(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TODAY'), findsNothing);
    final railSize = tester.getSize(find.byType(NavigationRail));
    // Non-extended rail (icon + label-below) is well under the extended 208.
    expect(railSize.width, lessThan(160));
  });
}
