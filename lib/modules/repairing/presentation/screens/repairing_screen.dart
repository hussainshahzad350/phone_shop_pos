import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
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

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(repairJobsProvider);
    ref.invalidate(repairKpisProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Repairing',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _refreshAll(ref),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _KpiRow(),
            const SizedBox(height: 12),
            const _FiltersRow(),
            const SizedBox(height: 8),
            const Expanded(child: _RepairJobsTable()),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(repairKpisProvider);

    return kpisAsync.when(
      data: (kpis) => Row(
        children: <Widget>[
          Expanded(
            child: _KpiCard(
              value: kpis.receivedToday.toString(),
              label: 'Received Today',
              icon: Icons.inbox_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiCard(
              value: kpis.readyForDelivery.toString(),
              label: 'Ready for Delivery',
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiCard(
              value: kpis.pendingRepairs.toString(),
              label: 'Pending Repairs',
              icon: Icons.build_outlined,
              iconColor: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiCard(
              value: FormattingHelpers.currencyPkr(kpis.todayEarnings),
              label: "Today's Earnings",
              icon: Icons.payments_outlined,
              iconColor: Colors.teal,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => SizedBox(
        height: 88,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
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
                onChanged: (v) =>
                    ref.read(repairJobsSearchQueryProvider.notifier).state = v,
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: statusFilter.isEmpty ? '' : statusFilter,
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
                ref.read(repairJobsStartDateProvider.notifier).state = picked;
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
                ref.read(repairJobsEndDateProvider.notifier).state = picked;
              },
              icon: const Icon(Icons.event, size: 16),
              label: Text(
                endDate == null
                    ? 'End Date'
                    : FormattingHelpers.dateYmd(endDate),
              ),
            ),
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
                ref.read(repairJobsSearchQueryProvider.notifier).state = '';
                ref.read(repairJobsStatusFilterProvider.notifier).state = '';
                ref.read(repairJobsStartDateProvider.notifier).state = null;
                ref.read(repairJobsEndDateProvider.notifier).state = null;
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Filters'),
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

    return jobsAsync.when(
      data: (jobs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AppDataTable(
            emptyMessage: 'No repair jobs found.',
            paginateThreshold: 40,
            columns: const <DataColumn>[
              DataColumn(label: Text('Job ID')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Problem')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Actions')),
            ],
            rows: jobs.map((job) => _buildRow(context, ref, job)).toList(
              growable: false,
            ),
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

  DataRow _buildRow(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job,
  ) {
    final shortId = job.id.length > 12 ? job.id.substring(job.id.length - 8) : job.id;

    final paymentText = job.finalCost != null
        ? 'Total: ${FormattingHelpers.currencyPkr(job.finalCost!)}\n'
            'Adv: ${FormattingHelpers.currencyPkr(job.advanceReceived)}\n'
            'Rem: ${FormattingHelpers.currencyPkr(job.remainingPayment)}'
        : job.estimatedCost != null
            ? 'Est: ${FormattingHelpers.currencyPkr(job.estimatedCost!)}'
            : '-';

    return DataRow(
      color: job.status == RepairJobEntity.statusReady
          ? WidgetStateProperty.all(Colors.green.shade50)
          : null,
      cells: <DataCell>[
        DataCell(
          Tooltip(
            message: job.id,
            child: Text('#$shortId', style: const TextStyle(fontSize: 12)),
          ),
        ),
        DataCell(Text(FormattingHelpers.dateYmd(job.repairDate))),
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(job.customerName ?? '-'),
              if (job.customerPhone != null)
                Text(
                  job.customerPhone!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(job.phoneModel),
              if (job.imei != null)
                Text(
                  'IMEI: ${job.imei}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 160,
            child: Text(
              job.problemDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(_StatusChip(status: job.status)),
        DataCell(
          Text(paymentText, style: const TextStyle(fontSize: 12)),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: () async {
                  final saved = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _RepairJobFormDialog(initialJob: job),
                  );
                  if (saved == true) {
                    ref.invalidate(repairJobsProvider);
                    ref.invalidate(repairKpisProvider);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => const AppConfirmationDialog(
                      title: 'Delete Repair Job',
                      message: 'Delete this repair job?',
                      confirmLabel: 'Delete',
                    ),
                  );
                  if (confirmed == true) {
                    final repository = await ref.read(
                      repairingRepositoryProvider.future,
                    );
                    final result = await repository.deleteRepairJob(job.id);
                    result.fold(
                      onSuccess: (_) {
                        ref.invalidate(repairJobsProvider);
                        ref.invalidate(repairKpisProvider);
                        AppNotifier.success('Repair job deleted.');
                      },
                      onFailure: (error) =>
                          AppNotifier.error(error.message),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      label: _statusLabel(status),
      color: _statusColor(status),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case RepairJobEntity.statusReceived:
      return Colors.grey;
    case RepairJobEntity.statusDiagnosing:
      return Colors.blue;
    case RepairJobEntity.statusRepairing:
      return Colors.orange;
    case RepairJobEntity.statusReady:
      return Colors.green;
    case RepairJobEntity.statusDelivered:
      return Colors.teal;
    case RepairJobEntity.statusCancelled:
      return Colors.red;
    default:
      return Colors.grey;
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

class _RepairJobFormDialog extends StatefulWidget {
  const _RepairJobFormDialog({this.initialJob});

  final RepairJobEntity? initialJob;

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
      _estimatedCostController.text =
          job.estimatedCost != null ? job.estimatedCost!.toStringAsFixed(0) : '';
      _advanceController.text = job.advanceReceived > 0
          ? job.advanceReceived.toStringAsFixed(0)
          : '';
      _finalCostController.text =
          job.finalCost != null ? job.finalCost!.toStringAsFixed(0) : '';
      _repairExpenseController.text = job.repairExpense > 0
          ? job.repairExpense.toStringAsFixed(0)
          : '';
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
      AppNotifier.error('Advance received must be >= 0.');
      return;
    }

    final finalCost = _parseOptionalAmount(_finalCostController.text);
    if (finalCost != null && finalCost < 0) {
      AppNotifier.error('Final cost must be >= 0.');
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
      repairDate: DateTime.utc(_repairDate.year, _repairDate.month, _repairDate.day),
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
        return AlertDialog(
          title: Text(isEditing ? 'Edit Repair Job' : 'Add Repair Job'),
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
                          onPressed: _isSubmitting
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
                          onChanged: (_) => setState(() {}),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _technicianController,
                          label: 'Technician (optional)',
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number (optional)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Problem'),
                  TextField(
                    controller: _problemController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Problem Description *',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _issueType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Issue Type (optional)',
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
                        onSelected: (_) => setState(() {
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _advanceController,
                          label: 'Advance Received',
                          numeric: true,
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _repairExpenseController,
                          label: 'Repair Expense',
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Status'),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Status *',
                    ),
                    items: RepairJobEntity.allStatuses
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (_isSubmitting || !_isValid)
                  ? null
                  : () => _submit(ref),
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool numeric = false,
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: label,
        hintText: hint,
      ),
      onChanged: onChanged != null ? (_) => onChanged() : null,
    );
  }
}
