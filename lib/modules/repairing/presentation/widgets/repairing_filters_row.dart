part of '../screens/repairing_screen.dart';

class _FiltersRow extends ConsumerWidget {
  const _FiltersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(repairJobsStatusFilterProvider);
    final startDate = ref.watch(repairJobsStartDateProvider);
    final endDate = ref.watch(repairJobsEndDateProvider);
    final includeArchived = ref.watch(repairJobsIncludeArchivedProvider);

    final actionButtons = <Widget>[
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
      OutlinedButton.icon(
        onPressed: () {
          ref.invalidate(repairJobsProvider);
          ref.invalidate(repairKpisProvider);
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Narrow windows: actions drop below the filters instead of the
            // fixed trailing buttons squeezing the filter wrap off-screen.
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildFilterWrap(
                    context,
                    ref,
                    statusFilter: statusFilter,
                    startDate: startDate,
                    endDate: endDate,
                    includeArchived: includeArchived,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actionButtons,
                  ),
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(
                  child: _buildFilterWrap(
                    context,
                    ref,
                    statusFilter: statusFilter,
                    startDate: startDate,
                    endDate: endDate,
                    includeArchived: includeArchived,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                actionButtons[0],
                const SizedBox(width: AppSpacing.sm),
                actionButtons[1],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterWrap(
    BuildContext context,
    WidgetRef ref, {
    required String statusFilter,
    required DateTime? startDate,
    required DateTime? endDate,
    required bool includeArchived,
  }) {
    return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
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
                      borderRadius: kAppDropdownMenuRadius,
                      menuMaxHeight: kAppDropdownMenuMaxHeight,
                      decoration: const InputDecoration(
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
    );
  }
}
