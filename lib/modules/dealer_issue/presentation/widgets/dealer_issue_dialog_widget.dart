import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';

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
            const SizedBox(height: 12),
            _buildImeiInput(),
            const SizedBox(height: 12),
            _buildImeiList(),
            const SizedBox(height: 12),
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
    final suppliersAsync = ref.watch(supplierListProvider);

    return suppliersAsync.when(
      data: (dealers) {
        if (dealers.isEmpty) {
          return const Text('No dealers available');
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedDealerId,
          decoration: const InputDecoration(
            labelText: 'Select Dealer',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: dealers.map((dealer) {
            return DropdownMenuItem<String>(
              value: dealer.id,
              child: Text(dealer.name),
            );
          }).toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDealerId = value;
              });
            }
          },
        );
      },
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
              labelText: 'Enter IMEI',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _addImei(),
          ),
        ),
        const SizedBox(width: 8),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selected IMEIs (${_selectedImeis.length}):',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
        border: OutlineInputBorder(),
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
