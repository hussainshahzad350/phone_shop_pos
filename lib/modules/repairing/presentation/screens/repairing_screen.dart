import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';
import 'package:phone_shop_pos/modules/repairing/presentation/providers/repairing_providers.dart';

const List<String> _kAccessoryChips = <String>[
  'Battery',
  'Back Cover',
  'SIM',
  'Memory Card',
  'Box',
  'Charger',
];

class RepairingScreen extends ConsumerWidget {
  const RepairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 12),
            const _KpiRow(),
            const SizedBox(height: 12),
            const _FiltersRow(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: const _RepairJobsTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  List<Widget> _buildCards(RepairKpiEntity kpis) {
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
        iconColor: Colors.green,
      ),
      _KpiCard(
        value: kpis.pendingRepairs.toString(),
        label: 'Pending Repairs',
        icon: Icons.build_outlined,
        iconColor: Colors.orange,
      ),
      _KpiCard(
        value: FormattingHelpers.currencyPkr(kpis.todayEarnings),
        label: "Today's Earnings",
        icon: Icons.payments_outlined,
        iconColor: Colors.teal,
      ),
      _KpiCard(
        value: FormattingHelpers.currencyPkr(kpis.allTimeEarnings),
        label: 'All Time Earnings',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: Colors.indigo,
      ),
      _KpiCard(
        value: kpis.allJobsDone.toString(),
        label: 'All Jobs Done',
        icon: Icons.done_all,
        iconColor: Colors.purple,
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
          final cards = _buildCards(kpis);
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

class _FiltersRow extends ConsumerWidget {
  const _FiltersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(repairJobsStatusFilterProvider);
    final startDate = ref.watch(repairJobsStartDateProvider);
    final endDate = ref.watch(repairJobsEndDateProvider);
    final includeArchived = ref.watch(repairJobsIncludeArchivedProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'Search',
                        hintText: 'Name, model, IMEI, phone…',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (v) => ref
                          .read(repairJobsSearchQueryProvider.notifier)
                          .state = v,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: statusFilter.isEmpty ? '' : statusFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'Status',
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All'),
                        ),
                        ...RepairJobEntity.allStatuses.map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(repairJobsStatusFilterProvider.notifier)
                          .state = v ?? '',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: startDate ?? DateTime.now(),
                      );
                      ref.read(repairJobsStartDateProvider.notifier).state =
                          picked;
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      startDate == null
                          ? 'Start Date'
                          : FormattingHelpers.dateYmd(startDate),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: endDate ?? DateTime.now(),
                      );
                      ref.read(repairJobsEndDateProvider.notifier).state =
                          picked;
                    },
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      endDate == null
                          ? 'End Date'
                          : FormattingHelpers.dateYmd(endDate),
                    ),
                  ),
                  FilterChip(
                    selected: includeArchived,
                    label: const Text('Include archived'),
                    onSelected: (selected) {
                      ref
                          .read(repairJobsIncludeArchivedProvider.notifier)
                          .state = selected;
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(repairJobsSearchQueryProvider.notifier).state =
                          '';
                      ref.read(repairJobsStatusFilterProvider.notifier).state =
                          '';
                      ref.read(repairJobsStartDateProvider.notifier).state =
                          null;
                      ref.read(repairJobsEndDateProvider.notifier).state = null;
                      ref
                          .read(repairJobsIncludeArchivedProvider.notifier)
                          .state = false;
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () async {
                final saved = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const _RepairJobFormDialog(),
                );
                if (saved == true) {
                  ref.invalidate(repairJobsProvider);
                  ref.invalidate(repairKpisProvider);
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Repair Job'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(repairJobsProvider);
                ref.invalidate(repairKpisProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepairJobsTable extends ConsumerWidget {
  const _RepairJobsTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(repairJobsProvider);
    final includeArchived = ref.watch(repairJobsIncludeArchivedProvider);

    return jobsAsync.when(
      data: (jobs) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _RepairJobsTableLayout.fromWidth(
                constraints.maxWidth,
              );
              final visibleColumns = _visibleColumns(layout);
              final columnWidths = _columnWidths(
                layout: layout,
                visibleColumns: visibleColumns,
                availableWidth: constraints.maxWidth,
              );

              return AppDataTable(
                emptyMessage: includeArchived
                    ? 'No archived repair jobs found.'
                    : 'No repair jobs found.',
                paginateThreshold: 40,
                showCheckboxColumn: false,
                columnSpacing: layout.columnSpacing,
                dataRowMinHeight: layout.dataRowMinHeight,
                dataRowMaxHeight: layout.dataRowMaxHeight,
                columns: visibleColumns
                    .map(
                      (column) => _buildColumn(
                        context,
                        column,
                        columnWidths,
                      ),
                    )
                    .toList(growable: false),
                rows: jobs.asMap().entries.map((entry) {
                  final rowIndex = entry.key;
                  final job = entry.value;
                  return _buildRow(
                    context,
                    ref,
                    job,
                    rowNumber: rowIndex + 1,
                    visibleColumns: visibleColumns,
                    columnWidths: columnWidths,
                  );
                }).toList(growable: false),
              );
            },
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Failed to load repair jobs.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(repairJobsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<_RepairJobsTableColumn> _visibleColumns(_RepairJobsTableLayout layout) {
    if (layout.showCompactColumns) {
      return const <_RepairJobsTableColumn>[
        _RepairJobsTableColumn.sr,
        _RepairJobsTableColumn.date,
        _RepairJobsTableColumn.customer,
        _RepairJobsTableColumn.status,
        _RepairJobsTableColumn.totalReceived,
        _RepairJobsTableColumn.remaining,
        _RepairJobsTableColumn.repairCost,
        _RepairJobsTableColumn.totalProfit,
        _RepairJobsTableColumn.actions,
      ];
    }
    if (layout.showMediumColumns) {
      return const <_RepairJobsTableColumn>[
        _RepairJobsTableColumn.sr,
        _RepairJobsTableColumn.date,
        _RepairJobsTableColumn.customer,
        _RepairJobsTableColumn.phone,
        _RepairJobsTableColumn.status,
        _RepairJobsTableColumn.totalReceived,
        _RepairJobsTableColumn.advance,
        _RepairJobsTableColumn.remaining,
        _RepairJobsTableColumn.repairCost,
        _RepairJobsTableColumn.totalProfit,
        _RepairJobsTableColumn.actions,
      ];
    }
    return const <_RepairJobsTableColumn>[
      _RepairJobsTableColumn.sr,
      _RepairJobsTableColumn.date,
      _RepairJobsTableColumn.customer,
      _RepairJobsTableColumn.phone,
      _RepairJobsTableColumn.problem,
      _RepairJobsTableColumn.status,
      _RepairJobsTableColumn.totalReceived,
      _RepairJobsTableColumn.advance,
      _RepairJobsTableColumn.remaining,
      _RepairJobsTableColumn.repairCost,
      _RepairJobsTableColumn.totalProfit,
      _RepairJobsTableColumn.actions,
    ];
  }

  Map<_RepairJobsTableColumn, double> _columnWidths({
    required _RepairJobsTableLayout layout,
    required List<_RepairJobsTableColumn> visibleColumns,
    required double availableWidth,
  }) {
    final widths = <_RepairJobsTableColumn, double>{
      for (final column in visibleColumns) column: layout.baseWidth(column),
    };

    final baseWidth =
        widths.values.fold<double>(0, (sum, value) => sum + value);
    final spacingWidth = (visibleColumns.length - 1) * layout.columnSpacing;
    final extraWidth = availableWidth - baseWidth - spacingWidth - 24;

    if (extraWidth > 0) {
      const weightedColumns = <_RepairJobsTableColumn, int>{
        _RepairJobsTableColumn.customer: 4,
        _RepairJobsTableColumn.phone: 4,
        _RepairJobsTableColumn.problem: 6,
        _RepairJobsTableColumn.totalReceived: 2,
        _RepairJobsTableColumn.advance: 2,
        _RepairJobsTableColumn.remaining: 2,
        _RepairJobsTableColumn.repairCost: 2,
        _RepairJobsTableColumn.totalProfit: 2,
      };
      final totalWeight = visibleColumns.fold<int>(
        0,
        (sum, column) => sum + (weightedColumns[column] ?? 0),
      );
      if (totalWeight > 0) {
        for (final column in visibleColumns) {
          final weight = weightedColumns[column] ?? 0;
          if (weight == 0) {
            continue;
          }
          widths[column] =
              widths[column]! + (extraWidth * weight / totalWeight);
        }
      }
    }

    if (extraWidth < 0) {
      const minWidths = <_RepairJobsTableColumn, double>{
        _RepairJobsTableColumn.sr: 40,
        _RepairJobsTableColumn.date: 86,
        _RepairJobsTableColumn.customer: 132,
        _RepairJobsTableColumn.phone: 124,
        _RepairJobsTableColumn.problem: 140,
        _RepairJobsTableColumn.status: 96,
        _RepairJobsTableColumn.totalReceived: 96,
        _RepairJobsTableColumn.advance: 90,
        _RepairJobsTableColumn.remaining: 96,
        _RepairJobsTableColumn.repairCost: 96,
        _RepairJobsTableColumn.totalProfit: 96,
        _RepairJobsTableColumn.actions: 122,
      };

      final shrinkableColumns = visibleColumns.where(
        (column) => (widths[column]! > (minWidths[column] ?? widths[column]!)),
      );

      final totalShrinkCapacity = shrinkableColumns.fold<double>(
        0,
        (sum, column) => sum + (widths[column]! - (minWidths[column] ?? 0)),
      );

      if (totalShrinkCapacity > 0) {
        final requiredShrink = -extraWidth;
        final appliedShrink = requiredShrink.clamp(0, totalShrinkCapacity);
        for (final column in shrinkableColumns) {
          final minWidth = minWidths[column] ?? widths[column]!;
          final capacity = widths[column]! - minWidth;
          if (capacity <= 0) {
            continue;
          }
          final shrinkBy = appliedShrink * (capacity / totalShrinkCapacity);
          widths[column] =
              (widths[column]! - shrinkBy).clamp(minWidth, double.infinity);
        }
      }
    }

    return widths;
  }

  DataColumn _buildColumn(
    BuildContext context,
    _RepairJobsTableColumn column,
    Map<_RepairJobsTableColumn, double> widths,
  ) {
    return DataColumn(
      numeric: false,
      label: _labelCell(
        context,
        _columnLabel(column),
        width: widths[column]!,
      ),
    );
  }

  String _columnLabel(_RepairJobsTableColumn column) {
    switch (column) {
      case _RepairJobsTableColumn.sr:
        return 'SR#';
      case _RepairJobsTableColumn.date:
        return 'Date';
      case _RepairJobsTableColumn.customer:
        return 'Customer';
      case _RepairJobsTableColumn.phone:
        return 'Phone';
      case _RepairJobsTableColumn.problem:
        return 'Problem';
      case _RepairJobsTableColumn.status:
        return 'Status';
      case _RepairJobsTableColumn.totalReceived:
        return 'Total Received (PKR)';
      case _RepairJobsTableColumn.advance:
        return 'Received So Far (PKR)';
      case _RepairJobsTableColumn.remaining:
        return 'Remaining (PKR)';
      case _RepairJobsTableColumn.repairCost:
        return 'Repair Cost (PKR)';
      case _RepairJobsTableColumn.totalProfit:
        return 'Total Profit (PKR)';
      case _RepairJobsTableColumn.actions:
        return 'Actions';
    }
  }

  Widget _labelCell(
    BuildContext context,
    String label, {
    required double width,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _textCell(
    String value, {
    required double width,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job, {
    required int rowNumber,
    required List<_RepairJobsTableColumn> visibleColumns,
    required Map<_RepairJobsTableColumn, double> columnWidths,
  }) {
    final isDelivered = job.status == RepairJobEntity.statusDelivered;
    final isArchived = job.isArchived;
    final canMarkDelivered = job.canMarkDelivered;

    String amountText(double value) {
      return FormattingHelpers.decimal(value, fractionDigits: 0);
    }

    DataCell cellFor(_RepairJobsTableColumn column) {
      switch (column) {
        case _RepairJobsTableColumn.sr:
          return DataCell(
            _textCell(rowNumber.toString(), width: columnWidths[column]!),
          );
        case _RepairJobsTableColumn.date:
          return DataCell(
            _textCell(
              FormattingHelpers.dateYmd(job.repairDate),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.customer:
          return DataCell(
            SizedBox(
              width: columnWidths[column],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(job.customerName ?? '-'),
                  if (job.customerPhone != null)
                    Text(
                      job.customerPhone!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          );
        case _RepairJobsTableColumn.phone:
          return DataCell(
            SizedBox(
              width: columnWidths[column],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(job.phoneModel),
                  if (job.imei != null)
                    Text(
                      'IMEI: ${job.imei}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          );
        case _RepairJobsTableColumn.problem:
          return DataCell(
            _textCell(
              job.problemDescription,
              width: columnWidths[column]!,
              maxLines: 2,
            ),
          );
        case _RepairJobsTableColumn.status:
          return DataCell(
            SizedBox(
              width: columnWidths[column],
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(status: job.status),
              ),
            ),
          );
        case _RepairJobsTableColumn.totalReceived:
          return DataCell(
            _textCell(
              amountText(job.totalReceived),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.advance:
          return DataCell(
            _textCell(
              amountText(job.advanceReceived),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.remaining:
          return DataCell(
            _textCell(
              amountText(job.remainingPayment),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.repairCost:
          return DataCell(
            _textCell(
              amountText(job.repairExpense),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.totalProfit:
          return DataCell(
            _textCell(
              amountText(job.netProfit),
              width: columnWidths[column]!,
            ),
          );
        case _RepairJobsTableColumn.actions:
          return DataCell(
            SizedBox(
              width: columnWidths[column],
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton.filledTonal(
                        icon: Icon(
                          isDelivered || isArchived
                              ? Icons.visibility_outlined
                              : Icons.edit_outlined,
                          size: 18,
                        ),
                        tooltip: (isDelivered || isArchived)
                            ? 'View Details'
                            : 'Edit',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final saved = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => _RepairJobFormDialog(
                              initialJob: job,
                              readOnly: isDelivered || isArchived,
                            ),
                          );
                          if (saved == true) {
                            ref.invalidate(repairJobsProvider);
                            ref.invalidate(repairKpisProvider);
                          }
                        },
                      ),
                      if (!isArchived &&
                          !isDelivered &&
                          job.hasPendingPayment) ...<Widget>[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          tooltip: 'Collect Payment',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final request =
                                await showDialog<_CollectPaymentRequest>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => _CollectPaymentDialog(job: job),
                            );
                            if (request == null) {
                              return;
                            }
                            final repository = await ref.read(
                              repairingRepositoryProvider.future,
                            );
                            final result = await repository.collectPayment(
                              job.id,
                              request.amount,
                              notes: request.notes,
                            );
                            result.fold(
                              onSuccess: (_) {
                                ref.invalidate(repairJobsProvider);
                                ref.invalidate(repairKpisProvider);
                                AppNotifier.success(
                                    'Payment collected successfully.');
                              },
                              onFailure: (error) =>
                                  AppNotifier.error(error.message),
                            );
                          },
                        ),
                      ],
                      if (isArchived) ...<Widget>[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.unarchive_outlined, size: 18),
                          tooltip: 'Unarchive',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => const AppConfirmationDialog(
                                title: 'Unarchive Repair Job',
                                message: 'Restore this archived repair job?',
                                confirmLabel: 'Unarchive',
                              ),
                            );
                            if (confirmed == true) {
                              final repository = await ref.read(
                                repairingRepositoryProvider.future,
                              );
                              final result =
                                  await repository.restoreRepairJob(job.id);
                              result.fold(
                                onSuccess: (_) {
                                  ref.invalidate(repairJobsProvider);
                                  ref.invalidate(repairKpisProvider);
                                  AppNotifier.success('Repair job unarchived.');
                                },
                                onFailure: (error) =>
                                    AppNotifier.error(error.message),
                              );
                            }
                          },
                        ),
                      ] else if (!isDelivered) ...<Widget>[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.local_shipping_outlined,
                              size: 18),
                          tooltip: canMarkDelivered
                              ? 'Mark Delivered'
                              : job.hasFinalPaymentAmount
                                  ? 'Cannot deliver while payment is pending'
                                  : 'Set final cost before delivery',
                          visualDensity: VisualDensity.compact,
                          onPressed: canMarkDelivered
                              ? () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => const AppConfirmationDialog(
                                      title: 'Mark Delivered',
                                      message:
                                          'Mark this repair as delivered and close editing?',
                                      confirmLabel: 'Mark Delivered',
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final repository = await ref.read(
                                      repairingRepositoryProvider.future,
                                    );
                                    final result =
                                        await repository.updateStatus(
                                      job.id,
                                      RepairJobEntity.statusDelivered,
                                    );
                                    result.fold(
                                      onSuccess: (_) {
                                        ref.invalidate(repairJobsProvider);
                                        ref.invalidate(repairKpisProvider);
                                        AppNotifier.success(
                                            'Repair marked delivered.');
                                      },
                                      onFailure: (error) =>
                                          AppNotifier.error(error.message),
                                    );
                                  }
                                }
                              : null,
                        ),
                      ],
                      if (!isArchived) ...<Widget>[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Archive',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AppConfirmationDialog(
                                title: 'Archive Repair Job',
                                message:
                                    'Archive this repair job? It will be hidden but preserved for audit.',
                                confirmLabel: 'Archive',
                              ),
                            );
                            if (confirmed == true) {
                              final repository = await ref.read(
                                repairingRepositoryProvider.future,
                              );
                              final result =
                                  await repository.deleteRepairJob(job.id);
                              result.fold(
                                onSuccess: (_) {
                                  ref.invalidate(repairJobsProvider);
                                  ref.invalidate(repairKpisProvider);
                                  AppNotifier.success('Repair job archived.');
                                },
                                onFailure: (error) =>
                                    AppNotifier.error(error.message),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
      }
    }

    return DataRow(
      color: job.status == RepairJobEntity.statusReady
          ? WidgetStateProperty.all(
              Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.35),
            )
          : null,
      cells: visibleColumns.map(cellFor).toList(growable: false),
    );
  }
}

enum _RepairJobsTableColumn {
  sr,
  date,
  customer,
  phone,
  problem,
  status,
  totalReceived,
  advance,
  remaining,
  repairCost,
  totalProfit,
  actions,
}

class _RepairJobsTableLayout {
  const _RepairJobsTableLayout({
    required this.columnSpacing,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.showMediumColumns,
    required this.showCompactColumns,
    required this.isWideDesktop,
  });

  final double columnSpacing;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showMediumColumns;
  final bool showCompactColumns;
  final bool isWideDesktop;

  factory _RepairJobsTableLayout.fromWidth(double width) {
    if (width >= 1600) {
      return const _RepairJobsTableLayout(
        columnSpacing: 16,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        showMediumColumns: false,
        showCompactColumns: false,
        isWideDesktop: true,
      );
    }
    if (width >= 1220) {
      return const _RepairJobsTableLayout(
        columnSpacing: 12,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        showMediumColumns: true,
        showCompactColumns: false,
        isWideDesktop: false,
      );
    }
    return const _RepairJobsTableLayout(
      columnSpacing: 10,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      showMediumColumns: false,
      showCompactColumns: true,
      isWideDesktop: false,
    );
  }

  double baseWidth(_RepairJobsTableColumn column) {
    if (isWideDesktop) {
      switch (column) {
        case _RepairJobsTableColumn.sr:
          return 56;
        case _RepairJobsTableColumn.date:
          return 120;
        case _RepairJobsTableColumn.customer:
          return 220;
        case _RepairJobsTableColumn.phone:
          return 220;
        case _RepairJobsTableColumn.problem:
          return 280;
        case _RepairJobsTableColumn.status:
          return 130;
        case _RepairJobsTableColumn.totalReceived:
          return 150;
        case _RepairJobsTableColumn.advance:
          return 130;
        case _RepairJobsTableColumn.remaining:
          return 140;
        case _RepairJobsTableColumn.repairCost:
          return 140;
        case _RepairJobsTableColumn.totalProfit:
          return 140;
        case _RepairJobsTableColumn.actions:
          return 176;
      }
    }
    if (showMediumColumns) {
      switch (column) {
        case _RepairJobsTableColumn.sr:
          return 52;
        case _RepairJobsTableColumn.date:
          return 110;
        case _RepairJobsTableColumn.customer:
          return 200;
        case _RepairJobsTableColumn.phone:
          return 190;
        case _RepairJobsTableColumn.problem:
          return 220;
        case _RepairJobsTableColumn.status:
          return 120;
        case _RepairJobsTableColumn.totalReceived:
          return 140;
        case _RepairJobsTableColumn.advance:
          return 120;
        case _RepairJobsTableColumn.remaining:
          return 130;
        case _RepairJobsTableColumn.repairCost:
          return 130;
        case _RepairJobsTableColumn.totalProfit:
          return 130;
        case _RepairJobsTableColumn.actions:
          return 168;
      }
    }
    switch (column) {
      case _RepairJobsTableColumn.sr:
        return 48;
      case _RepairJobsTableColumn.date:
        return 104;
      case _RepairJobsTableColumn.customer:
        return 170;
      case _RepairJobsTableColumn.phone:
        return 170;
      case _RepairJobsTableColumn.problem:
        return 180;
      case _RepairJobsTableColumn.status:
        return 112;
      case _RepairJobsTableColumn.totalReceived:
        return 120;
      case _RepairJobsTableColumn.advance:
        return 110;
      case _RepairJobsTableColumn.remaining:
        return 115;
      case _RepairJobsTableColumn.repairCost:
        return 115;
      case _RepairJobsTableColumn.totalProfit:
        return 115;
      case _RepairJobsTableColumn.actions:
        return 164;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _statusPillColors(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

({Color background, Color foreground}) _statusPillColors(
  String status,
  ColorScheme colorScheme,
) {
  switch (status) {
    case RepairJobEntity.statusReceived:
      return (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
    case RepairJobEntity.statusDiagnosing:
      return (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      );
    case RepairJobEntity.statusRepairing:
      return (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    case RepairJobEntity.statusReady:
      return (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    case RepairJobEntity.statusDelivered:
      return (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      );
    case RepairJobEntity.statusCancelled:
      return (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    default:
      return (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case RepairJobEntity.statusReceived:
      return 'Received';
    case RepairJobEntity.statusDiagnosing:
      return 'Diagnosing';
    case RepairJobEntity.statusRepairing:
      return 'Repairing';
    case RepairJobEntity.statusReady:
      return 'Ready';
    case RepairJobEntity.statusDelivered:
      return 'Delivered';
    case RepairJobEntity.statusCancelled:
      return 'Cancelled';
    default:
      return status;
  }
}

class _CollectPaymentRequest {
  const _CollectPaymentRequest({
    required this.amount,
    this.notes,
  });

  final double amount;
  final String? notes;
}

class _CollectPaymentDialog extends StatefulWidget {
  const _CollectPaymentDialog({required this.job});

  final RepairJobEntity job;

  @override
  State<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<_CollectPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.job.hasFinalPaymentAmount && widget.job.remainingPayment > 0) {
      _amountController.text = FormattingHelpers.decimal(
          widget.job.remainingPayment,
          fractionDigits: 0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    return FormattingHelpers.tryParseGroupedDecimalStrict(
      _amountController.text.trim(),
    );
  }

  void _submit() {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      AppNotifier.error('Enter a valid payment amount greater than zero.');
      return;
    }

    if (widget.job.hasFinalPaymentAmount &&
        amount > widget.job.remainingPayment + 0.009) {
      AppNotifier.error('Collected amount cannot exceed remaining payment.');
      return;
    }

    Navigator.of(context).pop(
      _CollectPaymentRequest(
        amount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final titleText = job.customerName?.trim().isNotEmpty == true
        ? job.customerName!
        : job.phoneModel;

    return AlertDialog(
      title: const Text('Collect Payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              titleText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Received so far: ${FormattingHelpers.currencyPkr(job.advanceReceived)}',
            ),
            Text(
              'Remaining: ${FormattingHelpers.currencyPkr(job.remainingPayment)}',
            ),
            if (job.hasFinalPaymentAmount)
              Text(
                'Final cost: ${FormattingHelpers.currencyPkr(job.finalCost ?? 0)}',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Amount to Collect',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Payment Notes (optional)',
                hintText: 'Cash, bank transfer, partial settlement…',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.payments_outlined, size: 16),
          label: const Text('Collect'),
        ),
      ],
    );
  }
}

class _RepairJobFormDialog extends StatefulWidget {
  const _RepairJobFormDialog({this.initialJob, this.readOnly = false});

  final RepairJobEntity? initialJob;
  final bool readOnly;

  @override
  State<_RepairJobFormDialog> createState() => _RepairJobFormDialogState();
}

class _RepairJobFormDialogState extends State<_RepairJobFormDialog> {
  late DateTime _repairDate;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _phoneModelController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _technicianController = TextEditingController();
  final TextEditingController _estimatedCostController =
      TextEditingController();
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _finalCostController = TextEditingController();
  final TextEditingController _repairExpenseController =
      TextEditingController();
  final TextEditingController _customAccessoryController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _status;
  String? _issueType;
  final Set<String> _selectedAccessories = <String>{};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final job = widget.initialJob;
    _repairDate =
        job != null ? job.repairDate.toLocal() : DateTimeHelpers.nowUtc();
    _status = job?.status ?? RepairJobEntity.statusReceived;
    _issueType = job?.issueType;

    if (job != null) {
      _customerNameController.text = job.customerName ?? '';
      _phoneNumberController.text = job.customerPhone ?? '';
      _phoneModelController.text = job.phoneModel;
      _imeiController.text = job.imei ?? '';
      _problemController.text = job.problemDescription;
      _technicianController.text = job.technicianName ?? '';
      _estimatedCostController.text = job.estimatedCost != null
          ? job.estimatedCost!.toStringAsFixed(0)
          : '';
      _advanceController.text =
          job.advanceReceived > 0 ? job.advanceReceived.toStringAsFixed(0) : '';
      _finalCostController.text =
          job.finalCost != null ? job.finalCost!.toStringAsFixed(0) : '';
      _repairExpenseController.text =
          job.repairExpense > 0 ? job.repairExpense.toStringAsFixed(0) : '';
      _notesController.text = job.notes ?? '';

      if (job.accessories != null && job.accessories!.isNotEmpty) {
        final parts = job.accessories!.split(',').map((s) => s.trim());
        for (final p in parts) {
          if (_kAccessoryChips.contains(p)) {
            _selectedAccessories.add(p);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _phoneModelController.dispose();
    _imeiController.dispose();
    _problemController.dispose();
    _technicianController.dispose();
    _estimatedCostController.dispose();
    _advanceController.dispose();
    _finalCostController.dispose();
    _repairExpenseController.dispose();
    _customAccessoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final model = _phoneModelController.text.trim();
    final problem = _problemController.text.trim();
    return model.isNotEmpty && problem.isNotEmpty;
  }

  String _buildAccessoriesString() {
    final parts = List<String>.from(_selectedAccessories);
    final custom = _customAccessoryController.text.trim();
    if (custom.isNotEmpty) {
      parts.add(custom);
    }
    return parts.join(', ');
  }

  double? _parseOptionalAmount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return FormattingHelpers.tryParseGroupedDecimalStrict(trimmed);
  }

  double _parseAmount(String text) {
    return FormattingHelpers.tryParseGroupedDecimalStrict(text.trim()) ?? 0;
  }

  Future<void> _submit(WidgetRef ref) async {
    final model = _phoneModelController.text.trim();
    final problem = _problemController.text.trim();
    if (model.isEmpty || problem.isEmpty) {
      AppNotifier.error('Phone Model and Problem Description are required.');
      return;
    }

    final estimatedCost = _parseOptionalAmount(_estimatedCostController.text);
    if (estimatedCost != null && estimatedCost < 0) {
      AppNotifier.error('Estimated cost must be >= 0.');
      return;
    }

    final advance = _parseAmount(_advanceController.text);
    if (advance < 0) {
      AppNotifier.error('Amount received must be >= 0.');
      return;
    }

    final finalCost = _parseOptionalAmount(_finalCostController.text);
    if (finalCost != null && finalCost < 0) {
      AppNotifier.error('Final cost must be >= 0.');
      return;
    }
    if (finalCost != null && finalCost > 0 && advance > finalCost) {
      AppNotifier.error('Amount received cannot exceed final cost.');
      return;
    }

    final repairExpense = _parseAmount(_repairExpenseController.text);
    if (repairExpense < 0) {
      AppNotifier.error('Repair expense must be >= 0.');
      return;
    }

    setState(() => _isSubmitting = true);
    final repository = await ref.read(repairingRepositoryProvider.future);
    final existing = widget.initialJob;
    final accessories = _buildAccessoriesString();

    final job = RepairJobEntity(
      id: existing?.id ?? IdHelpers.newId(prefix: 'rep'),
      repairDate:
          DateTime.utc(_repairDate.year, _repairDate.month, _repairDate.day),
      customerName: _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
      customerPhone: _phoneNumberController.text.trim().isEmpty
          ? null
          : _phoneNumberController.text.trim(),
      phoneModel: model,
      imei: _imeiController.text.trim().isEmpty
          ? null
          : _imeiController.text.trim(),
      problemDescription: problem,
      issueType: _issueType,
      accessories: accessories.isEmpty ? null : accessories,
      technicianName: _technicianController.text.trim().isEmpty
          ? null
          : _technicianController.text.trim(),
      estimatedCost: estimatedCost,
      advanceReceived: advance,
      finalCost: finalCost,
      repairExpense: repairExpense,
      status: _status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: existing?.createdAt ?? DateTimeHelpers.nowUtc(),
    );

    final result = existing == null
        ? await repository.addRepairJob(job)
        : await repository.updateRepairJob(job);

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(true),
      onFailure: (error) => AppNotifier.error(error.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isEditing = widget.initialJob != null;
        final isReadOnly = widget.readOnly;
        final editableStatuses = RepairJobEntity.allStatuses
            .where((status) => status != RepairJobEntity.statusDelivered)
            .toList(growable: false);
        return AlertDialog(
          title: Text(
            isReadOnly
                ? 'Repair Job Details'
                : (isEditing ? 'Edit Repair Job' : 'Add Repair Job'),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: SizedBox(
            width: 640,
            height: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildSectionHeader('Date & Device'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isSubmitting || isReadOnly)
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    initialDate: _repairDate,
                                  );
                                  if (picked != null) {
                                    setState(() => _repairDate = picked);
                                  }
                                },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            FormattingHelpers.dateYmd(_repairDate),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _phoneModelController,
                          label: 'Phone Model *',
                          enabled: !isReadOnly,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildTextField(
                          controller: _imeiController,
                          label: 'IMEI (optional)',
                          enabled: !isReadOnly,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _technicianController,
                          label: 'Technician (optional)',
                          enabled: !isReadOnly,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Customer'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildTextField(
                          controller: _customerNameController,
                          label: 'Customer Name (optional)',
                          enabled: !isReadOnly,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number (optional)',
                          enabled: !isReadOnly,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Problem'),
                  TextField(
                    controller: _problemController,
                    enabled: !isReadOnly,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Problem Description *',
                      labelStyle: isReadOnly
                          ? const TextStyle(color: Colors.black54)
                          : null,
                      disabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _issueType,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Issue Type (optional)',
                      labelStyle: _isSubmitting || isReadOnly
                          ? const TextStyle(color: Colors.black54)
                          : null,
                      disabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Not specified —'),
                      ),
                      ...RepairJobEntity.allIssueTypes.map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        ),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : isReadOnly
                            ? null
                            : (v) => setState(() => _issueType = v),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Accessories Received'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _kAccessoryChips.map((chip) {
                      final selected = _selectedAccessories.contains(chip);
                      return FilterChip(
                        label: Text(chip),
                        selected: selected,
                        onSelected: isReadOnly
                            ? null
                            : (_) => setState(() {
                                  if (selected) {
                                    _selectedAccessories.remove(chip);
                                  } else {
                                    _selectedAccessories.add(chip);
                                  }
                                }),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _customAccessoryController,
                    label: 'Other accessories (optional)',
                    hint: 'e.g. original box, back cover',
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Financials'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildTextField(
                          controller: _estimatedCostController,
                          label: 'Estimated Cost (optional)',
                          numeric: true,
                          enabled: !isReadOnly,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _advanceController,
                          label: 'Amount Received',
                          numeric: true,
                          enabled: !isReadOnly,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildTextField(
                          controller: _finalCostController,
                          label: 'Final Cost (optional)',
                          numeric: true,
                          enabled: !isReadOnly,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _repairExpenseController,
                          label: 'Repair Expense',
                          numeric: true,
                          enabled: !isReadOnly,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Status'),
                  if (isReadOnly)
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'Status',
                        labelStyle: TextStyle(color: Colors.black54),
                      ),
                      child: Text(
                        _statusLabel(_status),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'Status *',
                      ),
                      items: editableStatuses
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(_statusLabel(s)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (optional)',
                    maxLines: 2,
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(false),
              child: Text(isReadOnly ? 'Close' : 'Cancel'),
            ),
            if (!isReadOnly)
              FilledButton(
                onPressed:
                    (_isSubmitting || !_isValid) ? null : () => _submit(ref),
                child: Text(_isSubmitting
                    ? 'Saving…'
                    : (widget.initialJob != null ? 'Update' : 'Save')),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool numeric = false,
    int maxLines = 1,
    bool enabled = true,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: label,
        labelStyle: enabled ? null : const TextStyle(color: Colors.black54),
        hintText: hint,
        disabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      onChanged: onChanged != null ? (_) => onChanged() : null,
    );
  }
}
