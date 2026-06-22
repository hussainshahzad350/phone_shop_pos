part of '../screens/repairing_screen.dart';

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  List<Widget> _buildCards(BuildContext context, RepairKpiEntity kpis) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final semantic = theme.semantic;
    return <Widget>[
      _KpiCard(
        value: kpis.receivedToday.toString(),
        label: 'Received Today',
        icon: Icons.inbox_outlined,
      ),
      _KpiCard(
        value: kpis.readyForDelivery.toString(),
        label: 'Ready for Delivery',
        icon: Icons.check_circle_outline,
        iconColor: semantic.success,
      ),
      _KpiCard(
        value: kpis.pendingRepairs.toString(),
        label: 'Pending Repairs',
        icon: Icons.build_outlined,
        iconColor: semantic.warning,
      ),
      _KpiCard(
        value: FormattingHelpers.currencyPkr(kpis.todayEarnings),
        label: "Today's Earnings",
        icon: Icons.payments_outlined,
        iconColor: accent,
      ),
      _KpiCard(
        value: FormattingHelpers.currencyPkr(kpis.allTimeEarnings),
        label: 'All Time Earnings',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: accent,
      ),
      _KpiCard(
        value: kpis.allJobsDone.toString(),
        label: 'All Jobs Done',
        icon: Icons.done_all,
        iconColor: accent,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(repairKpisProvider);

    return kpisAsync.when(
      data: (kpis) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width - 20;
          final cards = _buildCards(context, kpis);
          final spacing = 8.0;
          final crossAxisCount = width >= 1500
              ? 5
              : width >= 1100
                  ? 4
                  : width >= 760
                      ? 3
                      : 2;
          final cardWidth =
              ((width - ((crossAxisCount - 1) * spacing)) / crossAxisCount)
                  .clamp(180.0, double.infinity);

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: cardWidth,
                    child: card,
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
      loading: () => const SizedBox(
        height: 188,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => SizedBox(
        height: 188,
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(repairKpisProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry KPIs'),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 32, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
