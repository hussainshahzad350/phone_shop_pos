import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/dialogs/dashboard_sales_invoice_dialog.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_low_stock_panel.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_recent_sales_panel.dart';

const double _dashboardNarrowWidthBreakpoint = 1220;

double _dashboardPanelHeightFor(double viewportHeight) {
  if (viewportHeight < 760) {
    return 280;
  }
  if (viewportHeight < 900) {
    return 340;
  }
  if (viewportHeight < 1080) {
    return 400;
  }
  return 480;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardServiceProvider);
    ref.invalidate(dashboardKpisProvider);
    ref.invalidate(dashboardRecentSalesProvider);
    ref.invalidate(dashboardLowStockProvider);
  }

  Future<void> _openInvoiceDialog(BuildContext context, String saleId) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DashboardSalesInvoiceDialog(saleId: saleId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final recentSalesAsync = ref.watch(dashboardRecentSalesProvider);
    final lowStockAsync = ref.watch(dashboardLowStockProvider);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f5): _RefreshDashboardIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RefreshDashboardIntent: CallbackAction<_RefreshDashboardIntent>(
            onInvoke: (_) {
              _refresh(ref);
              return null;
            },
          ),
        },
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow =
                  constraints.maxWidth < _dashboardNarrowWidthBreakpoint;
              final panelHeight =
                  _dashboardPanelHeightFor(constraints.maxHeight);
              return ListView(
                padding: const EdgeInsets.all(10),
                children: <Widget>[
                  DashboardHeader(onRefresh: () => _refresh(ref)),
                  const SizedBox(height: 8),
                  kpisAsync.when(
                    data: (kpis) => DashboardKpiGrid(kpis: kpis),
                    loading: () => const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 160,
                      child: Center(
                          child: Text('Failed to load dashboard metrics.')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isNarrow) ...<Widget>[
                    SizedBox(
                      height: panelHeight,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: recentSalesAsync.when(
                            data: (rows) => DashboardRecentSalesPanel(
                              rows: rows,
                              onOpenInvoice: (saleId) =>
                                  _openInvoiceDialog(context, saleId),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Center(
                              child: Text('Failed to load recent sales.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: panelHeight,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: lowStockAsync.when(
                            data: (rows) => DashboardLowStockPanel(rows: rows),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Center(
                              child: Text('Failed to load low stock data.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      height: panelHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 5,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: recentSalesAsync.when(
                                  data: (rows) => DashboardRecentSalesPanel(
                                    rows: rows,
                                    onOpenInvoice: (saleId) =>
                                        _openInvoiceDialog(context, saleId),
                                  ),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Center(
                                    child: Text('Failed to load recent sales.'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: lowStockAsync.when(
                                  data: (rows) =>
                                      DashboardLowStockPanel(rows: rows),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Center(
                                    child:
                                        Text('Failed to load low stock data.'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RefreshDashboardIntent extends Intent {
  const _RefreshDashboardIntent();
}
