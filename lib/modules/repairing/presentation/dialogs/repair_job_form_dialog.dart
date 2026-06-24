part of '../screens/repairing_screen.dart';

const List<String> _kAccessoryChips = <String>[
  'Battery',
  'Back Cover',
  'SIM',
  'Memory Card',
  'Box',
  'Charger',
];

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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Problem Description *',
                      labelStyle: isReadOnly
                          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                          : null,
                      disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _issueType,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Issue Type (optional)',
                      labelStyle: _isSubmitting || isReadOnly
                          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                          : null,
                      disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      child: Text(
                        _statusLabel(_status),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: label,
        labelStyle: enabled ? null : TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        hintText: hint,
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      onChanged: onChanged != null ? (_) => onChanged() : null,
    );
  }
}
