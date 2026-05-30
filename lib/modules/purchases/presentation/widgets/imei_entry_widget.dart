import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/cnic_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/imei_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

class ImeiEntryWidget extends StatefulWidget {
  const ImeiEntryWidget({
    required this.defaultCostPrice,
    this.isUsed = false,
    super.key,
  });

  final double defaultCostPrice;
  final bool isUsed;

  @override
  State<ImeiEntryWidget> createState() => _ImeiEntryWidgetState();
}

class _ImeiEntryWidgetState extends State<ImeiEntryWidget> {
  final TextEditingController _bulkController = TextEditingController();
  final TextEditingController _sellerNameController = TextEditingController();
  final TextEditingController _sellerIdCardController = TextEditingController();
  final TextEditingController _sellerAddressController =
      TextEditingController();
  final TextEditingController _warrantyController = TextEditingController();
  final TextEditingController _accessoriesController = TextEditingController();
  final TextEditingController _conditionNotesController =
      TextEditingController();
  final TextEditingController _sellerPhoneController = TextEditingController();

  late final ValueNotifier<List<_ParsedImeiLine>> _previewNotifier;
  double _defaultCost = 0;

  @override
  void initState() {
    super.initState();
    _defaultCost = widget.defaultCostPrice;
    _previewNotifier = ValueNotifier<List<_ParsedImeiLine>>(const []);
    _sellerNameController.addListener(_refreshConfirmState);
    _sellerIdCardController.addListener(_refreshConfirmState);
    _conditionNotesController.addListener(_refreshConfirmState);
  }

  @override
  void dispose() {
    _sellerNameController.removeListener(_refreshConfirmState);
    _sellerIdCardController.removeListener(_refreshConfirmState);
    _conditionNotesController.removeListener(_refreshConfirmState);
    _bulkController.dispose();
    _sellerNameController.dispose();
    _sellerIdCardController.dispose();
    _sellerAddressController.dispose();
    _warrantyController.dispose();
    _accessoriesController.dispose();
    _conditionNotesController.dispose();
    _sellerPhoneController.dispose();
    _previewNotifier.dispose();
    super.dispose();
  }

  void _parseInput(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final parsed = <_ParsedImeiLine>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,;\t]+'));
      final imei1 = parts.isNotEmpty ? ImeiHelpers.normalize(parts[0]) : '';
      if (imei1.isEmpty) {
        continue;
      }
      final imei2 =
          parts.length > 1 ? ImeiHelpers.normalizeNullable(parts[1]) : null;
      final serial = parts.length > 2 ? parts[2].trim() : null;
      parsed.add(_ParsedImeiLine(
        imei1: imei1,
        imei2: imei2?.isNotEmpty == true ? imei2 : null,
        serialNumber: serial?.isNotEmpty == true ? serial : null,
      ));
    }

    _previewNotifier.value = parsed;
    _refreshConfirmState();
  }

  void _refreshConfirmState() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canConfirm {
    if (_previewNotifier.value.isEmpty) {
      return false;
    }
    if (widget.isUsed) {
      if (_sellerNameController.text.trim().isEmpty) {
        return false;
      }
      if (_sellerIdCardController.text.trim().isEmpty) {
        return false;
      }
      if (CnicHelpers.errorText(_sellerIdCardController.text) != null) {
        return false;
      }
      if (_conditionNotesController.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isUsed ? 'Add Used Device IMEIs' : 'Add IMEI Entries'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Enter one device per line. Formats accepted:\n'
                '• IMEI1\n'
                '• IMEI1,IMEI2\n'
                '• IMEI1,IMEI2,SerialNumber',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Text('Default cost price: '),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: _defaultCost.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Cost',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final parsed = FormattingHelpers.parseLocaleDecimal(
                          v,
                          fallback: -1,
                        );
                        if (parsed >= 0) {
                          _defaultCost = parsed;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bulkController,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      '356789101234561\n356789101234562,356789101234570\n...',
                  labelText: 'Paste IMEIs here',
                ),
                onChanged: _parseInput,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<_ParsedImeiLine>>(
                valueListenable: _previewNotifier,
                builder: (context, preview, _) {
                  if (preview.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Preview: ${preview.length} device(s)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: preview.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = preview[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${index + 1}. ${entry.imei1}'
                                '${entry.imei2 != null ? " / ${entry.imei2}" : ""}'
                                '${entry.serialNumber != null ? " [${entry.serialNumber}]" : ""}',
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'monospace'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              if (widget.isUsed) ...<Widget>[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                Text(
                  'Seller & Condition Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildField(
                  controller: _sellerNameController,
                  label: 'Seller Name *',
                  required: true,
                ),
                const SizedBox(height: 8),
                _buildCnicField(),
                const SizedBox(height: 8),
                _buildField(
                  controller: _sellerPhoneController,
                  label: 'Seller Phone',
                  hint: 'e.g. 03001234567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                _buildField(
                  controller: _sellerAddressController,
                  label: 'Address',
                ),
                const SizedBox(height: 8),
                _buildField(
                  controller: _warrantyController,
                  label: 'Remaining Warranty',
                  hint: 'e.g. 3 months, none',
                ),
                const SizedBox(height: 8),
                _buildField(
                  controller: _accessoriesController,
                  label: 'Accessories Included',
                  hint: 'e.g. box, charger, earphones',
                ),
                const SizedBox(height: 8),
                _buildField(
                  controller: _conditionNotesController,
                  label: 'Phone Condition Notes *',
                  hint: 'Describe scratches, screen, battery etc.',
                  maxLines: 3,
                  required: true,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop<List<ImeiEntry>>(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !_canConfirm
              ? null
              : () {
                  final condition = widget.isUsed
                      ? SerializedStockCondition.used
                      : SerializedStockCondition.newPhone;
                  final sellerName =
                      widget.isUsed ? _sellerNameController.text.trim() : null;
                  final rawCnic = _sellerIdCardController.text.trim();
                  final sellerIdCard = widget.isUsed
                      ? (CnicHelpers.normalizeCnic(rawCnic) ?? rawCnic)
                      : null;
                  final sellerAddress = widget.isUsed
                      ? _nullIfEmpty(_sellerAddressController.text)
                      : null;
                  final sellerPhone = widget.isUsed
                      ? _nullIfEmpty(_sellerPhoneController.text)
                      : null;
                  final remainingWarranty = widget.isUsed
                      ? _nullIfEmpty(_warrantyController.text)
                      : null;
                  final accessories = widget.isUsed
                      ? _nullIfEmpty(_accessoriesController.text)
                      : null;
                  final phoneConditionNotes = widget.isUsed
                      ? _conditionNotesController.text.trim()
                      : null;

                  final entries = _previewNotifier.value
                      .map(
                        (p) => ImeiEntry(
                          imei1: p.imei1,
                          imei2: p.imei2,
                          serialNumber: p.serialNumber,
                          costPrice: _defaultCost,
                          condition: condition,
                          sellerName: sellerName,
                          sellerIdCard: sellerIdCard,
                          sellerAddress: sellerAddress,
                          sellerPhone: sellerPhone,
                          remainingWarranty: remainingWarranty,
                          accessories: accessories,
                          phoneConditionNotes: phoneConditionNotes,
                        ),
                      )
                      .toList(growable: false);
                  Navigator.of(context).pop<List<ImeiEntry>>(entries);
                },
          child: Text('Add ${_previewNotifier.value.length} Device(s)'),
        ),
      ],
    );
  }

  Widget _buildCnicField() {
    final errorText = CnicHelpers.errorText(_sellerIdCardController.text);
    return TextField(
      controller: _sellerIdCardController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        labelText: 'ID Card / CNIC *',
        hintText: 'XXXXX-XXXXXXX-X',
        errorText: errorText,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
      ),
    );
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ParsedImeiLine {
  const _ParsedImeiLine({
    required this.imei1,
    this.imei2,
    this.serialNumber,
  });

  final String imei1;
  final String? imei2;
  final String? serialNumber;
}
