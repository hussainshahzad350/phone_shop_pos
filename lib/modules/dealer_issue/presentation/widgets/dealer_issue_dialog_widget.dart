import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_providers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/add_dealer_dialog.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/app_searchable_dropdown_field.dart';

class DealerIssueDialogWidget extends ConsumerStatefulWidget {
  const DealerIssueDialogWidget({super.key});

  @override
  ConsumerState<DealerIssueDialogWidget> createState() => _DealerIssueDialogWidgetState();
}

class _DealerIssueDialogWidgetState extends ConsumerState<DealerIssueDialogWidget> {
  String? _selectedDealerId;
  final List<String> _selectedImeis = <String>[];
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _imeiController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue Device to Dealer'),
      content: SizedBox(
        width: 700,
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildDealerSelector(),
            const SizedBox(height: AppSpacing.md),
            _buildImeiInput(),
            const SizedBox(height: AppSpacing.md),
            _buildImeiList(),
            const SizedBox(height: AppSpacing.md),
            _buildNotes(),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Saving...' : 'Issue'),
        ),
      ],
    );
  }

  Widget _buildDealerSelector() {
    final dealersAsync = ref.watch(dealerListProvider);

    return dealersAsync.when(
      data: (dealers) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: AppSearchableDropdownField(
              value: _selectedDealerId,
              labelText: 'Select Dealer',
              hintText: dealers.isEmpty
                  ? 'No dealers — add one →'
                  : 'Search dealer',
              options: dealers
                  .map((d) => AppSelectOption(id: d.id, label: d.name))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _selectedDealerId = value);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: 'Add new dealer',
            icon: const Icon(Icons.person_add_outlined, size: 18),
            onPressed: () async {
              final created = await AddDealerDialog.show(context);
              if (created != null) {
                ref.invalidate(dealerListProvider);
                setState(() => _selectedDealerId = created.id);
              }
            },
          ),
        ],
      ),
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Failed to load dealers'),
    );
  }

  Widget _buildImeiInput() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _imeiController,
            decoration: const InputDecoration(
              labelText: 'Scan or enter IMEI',
              hintText: 'Scan barcode or type manually',
              isDense: true,
              prefixIcon: Icon(Icons.qr_code_scanner, size: 18),
            ),
            onSubmitted: (_) => _addImei(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: _addImei,
          icon: const Icon(Icons.add),
          tooltip: 'Add IMEI',
        ),
      ],
    );
  }

  void _addImei() {
    final imei = _imeiController.text.trim();
    if (imei.isEmpty) return;
    if (_selectedImeis.contains(imei)) {
      AppNotifier.warning('IMEI already added');
      return;
    }
    setState(() {
      _selectedImeis.add(imei);
      _imeiController.clear();
    });
  }

  Widget _buildImeiList() {
    if (_selectedImeis.isEmpty) {
      return const Text('No IMEIs selected');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selected IMEIs (${_selectedImeis.length}):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedImeis.map((imei) {
                return Chip(
                  label: Text(imei),
                  onDeleted: () {
                    setState(() {
                      _selectedImeis.remove(imei);
                    });
                  },
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes() {
    return TextField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes (optional)',
      ),
      maxLines: 3,
    );
  }

  Future<void> _submit() async {
    if (_selectedDealerId == null || _selectedDealerId!.isEmpty) {
      AppNotifier.error('Please select a dealer');
      return;
    }

    if (_selectedImeis.isEmpty) {
      AppNotifier.error('Please add at least one IMEI');
      return;
    }

    setState(() => _isSubmitting = true);

    await ref.read(dealerIssueStateProvider.notifier).createIssue(
      dealerId: _selectedDealerId!,
      imeiList: _selectedImeis,
      notes: _notesController.text.trim(),
    );
    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
