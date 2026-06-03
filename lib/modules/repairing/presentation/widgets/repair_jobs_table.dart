part of '../screens/repairing_screen.dart';

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
                  child: _RepairJobsRowActions(
                    isDelivered: isDelivered,
                    isArchived: isArchived,
                    hasPendingPayment: job.hasPendingPayment,
                    hasFinalPaymentAmount: job.hasFinalPaymentAmount,
                    canMarkDelivered: canMarkDelivered,
                    onViewOrEdit: () => _RepairingActionService.openJobForm(
                      context,
                      ref,
                      job,
                      readOnly: isDelivered || isArchived,
                    ),
                    onCollectPayment: () => _RepairingActionService.collectPayment(
                      context,
                      ref,
                      job,
                    ),
                    onUnarchive: () => _RepairingActionService.unarchiveJob(
                      context,
                      ref,
                      job,
                    ),
                    onMarkDelivered: canMarkDelivered
                        ? () => _RepairingActionService.markDelivered(
                            context,
                            ref,
                            job,
                          )
                        : null,
                    onArchive: () => _RepairingActionService.archiveJob(
                      context,
                      ref,
                      job,
                    ),
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
