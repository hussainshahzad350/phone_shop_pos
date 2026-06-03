part of '../screens/repairing_screen.dart';

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
